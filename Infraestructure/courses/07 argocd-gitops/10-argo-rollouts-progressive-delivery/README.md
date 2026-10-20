# argo-10 — Argo Rollouts: progressive delivery

## Identificación

- **ID:** `argo-10-argo-rollouts-progressive-delivery`
- **Curso:** `argocd-gitops`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `argo-04-sources-helm-kustomize-jsonnet-multisource`, `k8s-10-health-probes-lifecycle-and-rollouts`.

## Objetivo

Implementar y operar estrategias **blue/green** y **canary** nativas con **Argo Rollouts**, decidiendo entre división por réplicas y división por tráfico, y automatizando promoción y rollback con `AnalysisTemplate` sobre métricas Prometheus.

## Alcance

Este módulo cubre:

- Instalación de Argo Rollouts (CRDs + controller + plugin `kubectl argo rollouts`).
- El CRD **Rollout** como reemplazo de `Deployment` (misma `podTemplateSpec`, estrategia distinta).
- Estrategia **blue/green**: `activeService`, `previewService`, `autoPromotionEnabled`, `scaleDownDelaySeconds`.
- Estrategia **canary**: `steps` (`setWeight`, `pause`, `analysis`, `experiment`).
- **AnalysisTemplate** y **AnalysisRun** con `prometheus` provider (count de 5xx, p95 latency).
- **Traffic management**: cuándo el controller sólo puede dividir por *replicas* y cuándo por *peso real* (ingress-nginx, Istio, SMI, Gateway API, Traefik, ALB).
- Encaje con Argo CD (el `Rollout` es un recurso más que se aplica por GitOps; Argo CD lo marca healthy a través del *resource customization* oficial).

Lo que **no** cubre:

- Flagger (alternativa; sólo mención comparativa).
- Service Mesh profundo (Istio, Linkerd) — curso `k8s-15`.
- Instalación de Prometheus/Grafana — curso `observability`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-blue-green-with-services/` — un `Rollout` con dos Services (`active`, `preview`) y promoción manual.
  - `02-canary-stepped-with-nginx/` — un `Rollout` canary con pasos `setWeight`/`pause`, sin traffic management (división por réplicas).
  - `03-analysis-template-prom/` — un `AnalysisTemplate` que consulta Prometheus (`sum(rate(http_requests_total{code=~"5.."}[2m]))`) y gatea la promoción.
- **`activities/`**:
  - `01-canary-capstone/` (**guided-lab**) — construir un `Rollout` canary de 4 pasos (10% → pause → 50% → pause → 100%) para el capstone.
  - `02-auto-rollback-on-5xx/` (**independent**) — el estudiante escribe un `AnalysisTemplate` que consulta la tasa de 5xx en Prometheus y dispara auto-rollback cuando supera un umbral.
- **`resources/links.md`** — docs oficiales y referencias.

## Temas y subtemas

1. Por qué un `Deployment` no basta
   - Falta de atomicidad del switch, falta de análisis métrico, rollback no instantáneo.
2. Argo Rollouts — arquitectura
   - Controller + CRDs (`Rollout`, `AnalysisTemplate`, `AnalysisRun`, `Experiment`, `ClusterAnalysisTemplate`).
   - Plugin CLI `kubectl argo rollouts`.
3. CRD `Rollout`
   - `spec.replicas`, `selector`, `template` (idéntico a `Deployment`).
   - `spec.strategy.blueGreen` vs `spec.strategy.canary`.
   - `spec.workloadRef` (apuntar a un `Deployment` existente sin reescribir el template).
4. Blue/green
   - `activeService` y `previewService`.
   - `autoPromotionEnabled: false` → promoción manual (`kubectl argo rollouts promote`).
   - `scaleDownDelaySeconds` para que el ReplicaSet antiguo quede un rato (rollback caliente).
   - `prePromotionAnalysis` y `postPromotionAnalysis`.
5. Canary — modo "replica-based"
   - Sin traffic management: `setWeight: 20` crea un ReplicaSet nuevo con 20% de los pods.
   - Es *aproximado*: con 5 réplicas, 20% = 1 pod.
6. Canary — `steps`
   - `setWeight`, `pause` (indefinido o con `duration`), `analysis`, `experiment`, `setCanaryScale`.
7. Traffic management
   - `trafficRouting.nginx` (ingress-nginx: `canary-weight` annotation).
   - `trafficRouting.istio` (VirtualService con dos backends y pesos).
   - `trafficRouting.smi` (TrafficSplit CR).
   - `trafficRouting.plugins.argoproj-labs/gatewayAPI` (HTTPRoute con weighted backends).
   - `trafficRouting.alb` (AWS LB Controller con TargetGroupBinding).
   - `trafficRouting.traefik`.
   - Con traffic management el peso es *de requests*, no de pods: con 2 réplicas puedes decir 1%.
8. `AnalysisTemplate` y `AnalysisRun`
   - Providers: `prometheus`, `datadog`, `newrelic`, `cloudwatch`, `wavefront`, `web`, `job`, `kayenta`, `graphite`, `influxdb`.
   - `metrics[].successCondition`, `failureCondition`, `failureLimit`, `interval`, `count`.
   - `AnalysisRun` es el *job* creado por el controller cuando se dispara un step `analysis`; su resultado gatea la promoción.
9. `Experiment`
   - Correr una variante paralelo sin promocionarla (A/B puro, shadow traffic).
10. Integración con Argo CD
    - El `Rollout` se aplica como cualquier otro CR por GitOps.
    - Argo CD trae *health check* oficial para `Rollout`: `Progressing`, `Healthy`, `Degraded`, `Paused`, `Suspended`.
    - La promoción manual puede hacerse vía UI de Argo Rollouts, CLI (`kubectl argo rollouts promote`), o anotando el recurso en Git.
11. Rollback y abort
    - `kubectl argo rollouts abort <rollout>` — vuelve al estable sin esperar.
    - `undo` — equivalente a `kubectl rollout undo` pero con awareness de pasos canary.
    - Auto-rollback: cuando un `AnalysisRun` falla y `failureLimit` se excede, el Rollout entra en `Degraded` y revierte al estable automáticamente.
12. Checklist de progressive delivery seguro.

## Conceptos internos (fundamentos)

- El controller **no reemplaza** al `deployment-controller` del upstream K8s: gestiona sus propios `ReplicaSet`s. Si migras de `Deployment` a `Rollout` del mismo nombre, hay que borrar el Deployment antes (su RS se queda huérfano y el controller de Rollouts crea los suyos).
- **Sin traffic management**, el "weight" es una aproximación: `setWeight: 25` sobre `replicas: 4` da 1 pod en canario y 3 estables → 25%, pero sobre `replicas: 3` da también 1 pod y es 33%. El controller redondea.
- **Con traffic management**, el porcentaje es *de requests*, no de pods: puedes tener 2 réplicas canary y dirigir 1% del tráfico a través de la configuración del proxy (ingress-nginx, Istio, Gateway API).
- Un `AnalysisRun` es un recurso con fases `Pending → Running → Successful | Failed | Error | Inconclusive`. El controller consulta métricas en el `interval` definido y acumula resultados; `failureLimit: 3` significa "aborta si 3 muestras consecutivas violan `failureCondition`".
- `prePromotionAnalysis` en blue/green corre **antes** de hacer el switch del Service (preview → active). Si falla, el switch nunca ocurre — la versión nueva queda escalada en preview para que la inspecciones y hagas `undo`.
- El `health check` oficial de Argo CD para `Rollout` (en `argocd-cm.resource.customizations`) interpreta las fases del Rollout para que Argo CD no diga "Healthy" prematuramente — si el Rollout está `Paused` en un step manual, Argo CD lo refleja.

## Competencias

- **Conceptual** — explicar cuándo canary bate blue/green y viceversa; por qué un canary "replica-based" sin traffic management puede ser engañoso bajo caches/sticky sessions.
- **Operativa** — instalar Argo Rollouts, convertir un `Deployment` en `Rollout`, correr una promoción manual, escribir un `AnalysisTemplate` Prometheus y verificar auto-rollback.
- **Arquitectónica** — decidir el nivel de traffic management necesario según el servicio (REST stateless vs gRPC long-lived vs sticky); diseñar criterios de analysis realistas (SLI-based) con `successCondition` numéricas.

## Ejemplos

- [`examples/01-blue-green-with-services/`](examples/01-blue-green-with-services/) — blue/green con `activeService` + `previewService` y promoción manual.
- [`examples/02-canary-stepped-with-nginx/`](examples/02-canary-stepped-with-nginx/) — canary 10 → 25 → 50 → 100 con `pause` y traffic routing ingress-nginx (opcional; funciona también replica-based).
- [`examples/03-analysis-template-prom/`](examples/03-analysis-template-prom/) — `AnalysisTemplate` Prometheus para error-rate.

## Actividades

- [`activities/01-canary-capstone/`](activities/01-canary-capstone/) — guided-lab: canary de 4 pasos para el capstone.
- [`activities/02-auto-rollback-on-5xx/`](activities/02-auto-rollback-on-5xx/) — independent: escribir un `AnalysisTemplate` que mida 5xx en Prometheus y dispare auto-rollback.

## Entregables

- Capstone con un `Rollout` canary de 4+ pasos aplicado por Argo CD.
- `AnalysisTemplate` Prometheus que gatea la promoción y provoca auto-rollback si supera el umbral.
- ADR corto justificando: estrategia elegida (BG vs canary), nivel de traffic management, criterios de analysis (SLI, umbral, ventana).

## Criterios de evaluación

- **Conceptual** — explicar la diferencia entre `setWeight` *replica-based* y *traffic-based* y qué garantiza cada uno.
- **Operativa** — dado un `Deployment`, convertirlo en `Rollout` canary con analysis Prometheus y demostrar un auto-rollback forzado.
- **Arquitectónica** — proponer el `AnalysisTemplate` para un servicio dado (REST, gRPC, batch) con SLIs apropiados y defender los umbrales.

## Recursos

Ver [`resources/links.md`](resources/links.md).
