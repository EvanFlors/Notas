# argo-10 — Argo Rollouts: lección

> Progressive delivery nativa en Kubernetes con `Rollout`, `AnalysisTemplate` y traffic management. Diseñada para encajar sobre Argo CD, pero el `Rollout` es un CR igual que cualquier otro — no requiere Argo CD para funcionar.

---

## 1. Por qué un `Deployment` no basta

Un `Deployment` estándar hace un `RollingUpdate` controlado por `maxSurge`/`maxUnavailable` (visto en `k8s-10`). Es sencillo, suficiente para la mayoría, y tiene tres límites duros:

1. **No es atómico**. Durante el rollout coexisten las dos versiones recibiendo tráfico mezclado; si la nueva es defectuosa, los errores los ven usuarios *mientras* el rollout avanza. El rollback (`kubectl rollout undo`) revierte la deployment pero hay un cuarto de hora de ventana en que una fracción de usuarios ya tocó la mala.
2. **No tiene criterios de promoción**. El `Deployment` promueve siempre, en cuanto los Pods pasan `readinessProbe`. "Ready" sólo dice "el proceso contesta"; no dice "no está generando 5xx" ni "p95 no se degradó".
3. **No separa switch de deploy**. En blue/green el ideal es *tener la nueva versión completamente escalada y verificada* y *luego* mover tráfico. Con `Deployment` eso requiere un dance de dos Deployments + un Service que se re-labelea manualmente.

**Argo Rollouts** añade el CR `Rollout` que resuelve los tres: estrategia `blueGreen` (switch atómico de Service) y `canary` con `steps` donde cada paso puede ser `setWeight`, `pause` o `analysis`.

Alternativas en el ecosistema: **Flagger** (operador equivalente, acoplado más fuerte a service meshes), **Service Mesh con TrafficSplit manual** (más low-level), **Spinnaker** (push-based, otra filosofía). Argo Rollouts es el estándar de facto por su integración natural con Argo CD y por no exigir service mesh.

## 2. Arquitectura de Argo Rollouts

Un controller + 5 CRDs:

| CR | Rol |
|----|-----|
| `Rollout` | Reemplaza a `Deployment`. Mismo `podTemplateSpec`, estrategia distinta. |
| `AnalysisTemplate` | Plantilla reutilizable de métricas (`metrics` + providers). |
| `ClusterAnalysisTemplate` | Igual pero cluster-scoped. |
| `AnalysisRun` | Instancia concreta disparada por un step `analysis` o manualmente. |
| `Experiment` | Correr una variante en paralelo sin promocionarla (shadow / A/B puro). |

Instalación típica:

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Plugin kubectl (ejecútalo también en tu máquina local para la UX):
# curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
# chmod +x kubectl-argo-rollouts-linux-amd64 && sudo mv ... /usr/local/bin/kubectl-argo-rollouts
```

Vía Argo CD (el patrón real): un `Application` que apunta al chart oficial o al manifest y lo mantiene reconciliado. La UX añadida es el **dashboard** del plugin (`kubectl argo rollouts dashboard`), muy útil durante promociones.

## 3. El CRD `Rollout`

Estructura mínima:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  replicas: 5
  selector:
    matchLabels:
      app: my-app
  template:                 # idéntico a Deployment.spec.template
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: app
          image: ghcr.io/me/my-app:v1
          ports:
            - { name: http, containerPort: 8080 }
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: { duration: 1m }
        - setWeight: 50
        - pause: {}            # pause indefinido → requiere `promote`
        - setWeight: 100
```

Dos variantes de autoring:

- **Template inline** (arriba): el `template` vive dentro del `Rollout`.
- **`workloadRef`**: el `Rollout` apunta a un `Deployment` existente. Útil cuando migras incrementalmente — el chart de Helm sigue produciendo un `Deployment`, y añades un `Rollout` encima.

```yaml
spec:
  workloadRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app      # el Deployment debe tener replicas: 0 (lo escala el Rollout)
```

**Trampa**: si el `Deployment` del nombre existe con replicas > 0, hay doble gestor. Patrón correcto: `workloadRef` apunta a un `Deployment` con `replicas: 0` que sólo sirve de template.

## 4. Blue/green

Patrón "dos Services, un Rollout":

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata: { name: bg-app }
spec:
  replicas: 3
  selector: { matchLabels: { app: bg-app } }
  template:
    metadata: { labels: { app: bg-app } }
    spec:
      containers: [{ name: app, image: ghcr.io/me/bg-app:v1, ports: [{ containerPort: 80 }] }]
  strategy:
    blueGreen:
      activeService: bg-app-active
      previewService: bg-app-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 60
      prePromotionAnalysis:
        templates:
          - templateName: error-rate
```

Comportamiento al cambiar la imagen:

1. El controller crea un **nuevo ReplicaSet** con la imagen nueva, escalado a `spec.replicas`.
2. El `previewService` empieza a seleccionar el RS nuevo (via `rollouts-pod-template-hash` label).
3. `prePromotionAnalysis` corre contra el nuevo (que recibe tráfico sólo por `previewService` — ideal para smoke de QA).
4. Si pasa el analysis y `autoPromotionEnabled: true`, el `activeService` se repunta al RS nuevo (switch atómico, ms).
5. Con `autoPromotionEnabled: false`, el controller queda en `Paused` y requiere `kubectl argo rollouts promote bg-app`.
6. `scaleDownDelaySeconds: 60`: el RS viejo queda escalado 60 s por si hay que *rollback caliente* (`abort`).

**Observación**: durante `preview`, el RS viejo sigue sirviendo el 100% del tráfico de producción. El switch es atómico desde el punto de vista del Service — pero las conexiones *ya establecidas* al RS viejo siguen hasta que mueran o se cierren. Para conexiones persistentes (gRPC long-lived, websockets) necesitas `preStop` + `terminationGracePeriodSeconds` como en `k8s-10`.

## 5. Canary — modo "replica-based"

Sin traffic management, el controller sólo puede dividir por *pods*:

```yaml
strategy:
  canary:
    steps:
      - setWeight: 20
      - pause: { duration: 2m }
      - setWeight: 50
      - pause: {}
      - setWeight: 100
```

Con `replicas: 5` y `setWeight: 20`, el controller mantiene 1 pod canario y 4 estables; el Service `my-app` selecciona por el label común y balancea round-robin — 1 de cada 5 requests llega al canario, *en promedio*, si las conexiones son stateless y cortas.

Si las conexiones son **sticky** (sessions a nivel LB), o hay **cache** aguas arriba, el porcentaje de usuarios expuestos puede ser muy distinto del porcentaje de pods. Es la trampa clásica del canary replica-based.

**Fórmula de redondeo**: `canaryReplicas = ceil(replicas * weight / 100)`. Con 3 réplicas y `setWeight: 10`, el controller sube `max(1, ...)` → 1 canary, 33% real. Para pesos finos necesitas o muchas réplicas o traffic management.

## 6. Canary — `steps` en profundidad

Los pasos corren secuencialmente. Tipos:

- `setWeight: N` — ajusta % canary y escala.
- `pause: {}` — pausa indefinido; requiere `promote` manual.
- `pause: { duration: 5m }` — pausa temporizado.
- `analysis: { templates: [{ templateName: foo }] }` — dispara `AnalysisRun`; si falla, abort.
- `experiment: { duration: 5m, templates: [...] }` — corre un segundo RS experimental; útil para A/B.
- `setCanaryScale: { weight: 50 }` o `{ replicas: 2 }` — override del scale cuando traffic management desacopla peso de réplicas.

Patrón recomendado para prod:

```yaml
steps:
  - setWeight: 5
  - pause: { duration: 2m }
  - analysis: { templates: [{ templateName: error-rate-5xx }] }
  - setWeight: 25
  - pause: { duration: 5m }
  - analysis: { templates: [{ templateName: error-rate-5xx }, { templateName: latency-p95 }] }
  - setWeight: 50
  - pause: {}        # gate humano antes del 100%
  - setWeight: 100
```

## 7. Traffic management

Sin traffic routing, el canary comparte el mismo Service que el estable y el porcentaje es *de pods*. Con traffic routing, el controller programa el proxy para que divida por *requests*.

| Provider | CR/mecanismo | Nota |
|----------|--------------|------|
| **ingress-nginx** | 2 Ingress; el canary tiene `nginx.ingress.kubernetes.io/canary: "true"` y `canary-weight` ajustado por el controller. | Simple, ampliamente desplegado. |
| **Istio** | 1 `VirtualService` con 2 `destination` rules y pesos ajustados. | Requiere Istio instalado. |
| **SMI (TrafficSplit)** | CR `TrafficSplit` ajustado por el controller. | Spec abierta; Linkerd implementa. |
| **Gateway API** | `HTTPRoute` con `backendRefs` pesados. | Plugin `argoproj-labs/gatewayAPI`. Futuro estándar. |
| **ALB** | AWS LB Controller + TargetGroupBinding con dos TG. | AWS-only. |
| **Traefik** | `TraefikService` ponderado. | |

Ejemplo con ingress-nginx:

```yaml
spec:
  strategy:
    canary:
      canaryService: my-app-canary       # Service que selecciona sólo RS nuevo
      stableService: my-app-stable       # Service que selecciona sólo RS estable
      trafficRouting:
        nginx:
          stableIngress: my-app          # Ingress existente; el controller crea my-app-canary
      steps: [...]
```

El controller crea y mantiene un Ingress hermano con `canary: "true"` y actualiza su annotation `canary-weight` en cada `setWeight`.

**Elección práctica**: si ya corre ingress-nginx, úsalo. Si ya corre Istio/Linkerd, úsalos. Si estás empezando, Gateway API es la apuesta a futuro. Si no hay ninguno, canary replica-based + conciencia de sus límites.

## 8. `AnalysisTemplate` y `AnalysisRun`

El `AnalysisTemplate` define *qué medir y cuándo pasa/falla*:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata: { name: error-rate-5xx }
spec:
  args:
    - name: service-name
  metrics:
    - name: error-rate
      interval: 30s
      count: 5
      successCondition: result[0] <= 0.01
      failureLimit: 2
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc:9090
          query: |
            sum(rate(http_requests_total{service="{{args.service-name}}",code=~"5.."}[2m]))
            /
            sum(rate(http_requests_total{service="{{args.service-name}}"}[2m]))
```

Lectura:

- `interval: 30s` — cada 30 s el controller consulta Prometheus.
- `count: 5` — toma 5 muestras y luego da `Successful`.
- `successCondition: result[0] <= 0.01` — expresión Go-template. `result` es array de valores del query (ejecución Prometheus).
- `failureLimit: 2` — si 2 muestras violan `successCondition`, el `AnalysisRun` da `Failed` → el `Rollout` entra en `Degraded` y hace *abort* (vuelve al estable).

Providers: `prometheus`, `datadog`, `newrelic`, `cloudwatch`, `wavefront`, `graphite`, `influxdb`, `kayenta`, `web` (HTTP arbitrario), `job` (K8s Job con exit 0 = success).

Un step `analysis` referencia la plantilla:

```yaml
- analysis:
    templates:
      - templateName: error-rate-5xx
    args:
      - name: service-name
        value: my-app
```

El controller crea un `AnalysisRun` cuyo nombre es `<rollout>-<revision>-<index>`. Puedes inspeccionarlo:

```bash
kubectl get analysisruns -l rollout=my-app
kubectl describe analysisrun my-app-6-2
```

Fases: `Pending → Running → Successful | Failed | Error | Inconclusive`.

**Diseño de SLIs**:

- *Error rate*: `rate(http_5xx[2m]) / rate(http_total[2m])`. Umbral típico: ≤ 1% o ≤ baseline + 0.5%.
- *Latency p95*: `histogram_quantile(0.95, rate(http_duration_bucket[2m]))`. Umbral: ≤ baseline × 1.2.
- *Saturation*: CPU, memoria, colas. Útil pero más ruidoso.

Siempre comparar canary vs stable, no canary vs absolutos: la query típica compara `{version="canary"}` contra `{version="stable"}` para evitar que un pico global dispare un rollback injustificado.

## 9. `Experiment`

Un `Experiment` corre un segundo ReplicaSet por un tiempo determinado, sin cambiar `setWeight` del Rollout. Casos:

- *Shadow traffic*: mandar el 1% del tráfico a una variante que ni siquiera responde al usuario (hay que combinar con mesh / mirror en Istio).
- *A/B puro*: dos variantes servidas a cohortes etiquetadas, decisión por métricas de negocio.

Para el curso basta saber que existe; el 99% del valor está en `canary` + `analysis`.

## 10. Integración con Argo CD

Un `Rollout` es un CR estándar: `argocd app sync` lo aplica. Dos sutilezas:

- **Health check**. Argo CD trae un *resource customization* oficial que mapea las fases de `Rollout` (`Progressing`, `Healthy`, `Paused`, `Degraded`) al status de Argo CD. Si tu versión de Argo CD es antigua y no lo trae, hay que añadirlo al `argocd-cm`:

```yaml
data:
  resource.customizations: |
    argoproj.io/Rollout:
      health.lua: |
        -- ver docs oficiales: argo-rollouts/docs/features/argocd
```

- **Promoción manual desde Git**. Para `pause: {}` indefinido hay 3 opciones:
  1. CLI: `kubectl argo rollouts promote <rollout>`.
  2. UI del dashboard Argo Rollouts.
  3. **GitOps-puro**: añadir en Git una anotación `rollout.argoproj.io/promote-full: "true"` al `Rollout` y commitear. Argo CD la reconcilia, el controller la lee y promueve. Es el único enfoque consistente con "Git es la fuente de verdad".

## 11. Rollback y abort

- **Abort**: `kubectl argo rollouts abort my-app` — vuelve al estable inmediatamente (scale canary a 0, routing al 0%). No borra el `Rollout`; queda `Degraded`. Para reintentar hay que `retry` o push de una revisión nueva.
- **Undo**: `kubectl argo rollouts undo my-app --to-revision=N` — revierte a una revisión anterior respetando `steps`.
- **Auto-rollback**: cuando un `AnalysisRun` falla, el controller gatilla abort automáticamente. Es la *razón de ser* del progressive delivery.
- Si `scaleDownDelaySeconds` está puesto en blue/green (recomendado), el RS viejo sigue corriendo tras la promoción N segundos; un `abort` dentro de esa ventana es instantáneo (switch de Service de vuelta). Fuera de ella hay que esperar reinicio del RS viejo.

## 12. Checklist de progressive delivery seguro

- [ ] `Rollout` sustituye al `Deployment` (sin convivir ambos con el mismo selector).
- [ ] Para blue/green: `activeService` y `previewService` con selectores idénticos al `Rollout.spec.selector`.
- [ ] Para canary >5% real: traffic management configurado (ingress-nginx / Istio / Gateway API).
- [ ] Al menos un step `analysis` entre el 25% y el 100%.
- [ ] `AnalysisTemplate` con `successCondition` numérico y `failureLimit >= 2` (evitar flapping).
- [ ] Queries Prometheus comparan canary vs stable, no absolutos.
- [ ] `prePromotionAnalysis` configurado en blue/green antes del switch.
- [ ] `scaleDownDelaySeconds >= 60` para rollback caliente.
- [ ] `kubectl argo rollouts status` corriendo en CI que dispara el deploy, con `--watch` y timeout.
- [ ] Promoción manual (`pause: {}`) tiene SOP documentado (quién, cómo, con qué checklist).
- [ ] Alertas Prometheus/alertmanager sobre `rollout_phase{phase="Degraded"}`.

---

**Siguiente módulo**: `argo-11-internals-and-security` — endurecer Argo CD, SSO, backup/restore.
