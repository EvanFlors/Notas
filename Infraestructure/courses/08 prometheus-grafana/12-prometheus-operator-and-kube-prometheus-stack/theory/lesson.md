# obs-12 — Prometheus Operator y kube-prometheus-stack

> Lección en 12 secciones. Español en prosa, inglés en código, nombres de recursos y comandos.

---

## 1. Por qué existe el Operator

Antes de K8s, operar Prometheus era: editar `prometheus.yml`, listar targets, `SIGHUP` para recargar. En Kubernetes esto se degrada rápido:

- **Churn de pods**: las IPs cambian constantemente; `static_configs` no sirve.
- **Multi-tenant**: cada equipo quiere su propio Prometheus; mantener N `prometheus.yml` a mano no escala.
- **Observabilidad "self-serve"**: el equipo dueño de una app debería poder *declarar* "scrape mi `/metrics`" sin pedir a plataforma que edite un YAML global.

La respuesta en K8s es un **Operator** (patrón introducido por CoreOS en 2016): un controller que observa recursos personalizados (CRDs) y materializa el estado. En este caso:

```
CR (ServiceMonitor) → Operator → prometheus.yml generado → Secret → Pod Prometheus (reload)
```

El estudiante **nunca** escribe `prometheus.yml` otra vez. Escribe `ServiceMonitor`, `PodMonitor`, `PrometheusRule`. El Operator los traduce.

Esto no es solo comodidad: es la **unidad de observabilidad como código** que GitOps necesita.

---

## 2. Arquitectura del Prometheus Operator

Componentes:

- **`prometheus-operator`** (Deployment): el controller. Observa CRDs en el cluster.
- **CRDs** registrados: `Prometheus`, `Alertmanager`, `ThanosRuler`, `ServiceMonitor`, `PodMonitor`, `Probe`, `ScrapeConfig`, `PrometheusRule`, `AlertmanagerConfig`.
- **Prometheus `StatefulSet`**: generado por el Operator a partir de un CR `Prometheus`.
- **`Secret` `prometheus-<name>`**: contiene el `prometheus.yml` *generado*. El Pod lo monta read-only.
- **`configmap-reloader` sidecar**: detecta cambios en el Secret y envía `SIGHUP` al proceso Prometheus para recargar sin reiniciar.

Flujo completo cuando creas un `ServiceMonitor`:

1. `kubectl apply -f sm.yaml`.
2. El controller detecta el nuevo CR.
3. Si pasa los selectors del `Prometheus` CR (ver §6), lo incluye en el `prometheus.yml` generado.
4. Actualiza el Secret.
5. Reloader detecta el cambio.
6. `SIGHUP` → Prometheus recarga su config.
7. En segundos, los nuevos targets aparecen en `/service-discovery`.

**Punto clave**: debajo sigue siendo Prometheus *normal*. El `prometheus.yml` resultante es inspeccionable con `kubectl get secret prometheus-<name> -o jsonpath='{.data.prometheus\.yaml\.gz}' | base64 -d | gunzip`.

---

## 3. `kube-prometheus-stack`: lo que trae

El chart `prometheus-community/kube-prometheus-stack` (origen: el proyecto `kube-prometheus` de la comunidad Prometheus Operator) empaqueta:

| Componente              | Rol                                                        |
|-------------------------|------------------------------------------------------------|
| `prometheus-operator`   | Controller que ya vimos.                                   |
| `Prometheus` CR         | Un Prometheus con retention, resources, selectors por default. |
| `Alertmanager` CR       | Un Alertmanager HA (2 replicas por default en prod).       |
| Grafana                 | UI con sidecar que carga dashboards desde ConfigMaps.      |
| `node-exporter`         | DaemonSet con métricas del host (CPU, RAM, disco, red).    |
| `kube-state-metrics`    | Deployment con métricas del estado de objetos K8s (Pod phase, Deployment replicas, PVC bound, etc.). |
| `kubernetes-mixin`      | ~40 dashboards + ~70 alertas listas, mantenidas por SIG-Instrumentation. |

Es el "default" moderno porque:

1. Resuelve el 80% de observabilidad K8s con `helm install`.
2. Las dashboards y alertas de la mixin están **battle-tested**.
3. Toda la configuración pasa a ser YAML declarativo (CRs + values del chart).

Precio: el chart es grande (~500 MB de imágenes) y asume ≥ 4 GB RAM libres en el cluster.

---

## 4. CRDs de scrape: `ServiceMonitor`, `PodMonitor`, `Probe`, `ScrapeConfig`

### 4.1 `ServiceMonitor`

El más usado. Scrapea los **endpoints** de un `Service`.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: fastapi-app
  namespace: apps
  labels:
    release: kps          # ← crítico, ver §6
spec:
  selector:
    matchLabels:
      app: fastapi
  namespaceSelector:
    matchNames: [apps]
  endpoints:
    - port: http          # nombre del port del Service, no número
      path: /metrics
      interval: 30s
```

Debajo, se traduce a un `scrape_config` con `role: endpoints` + relabel que filtra por las labels del Service.

### 4.2 `PodMonitor`

Scrapea Pods directamente, sin pasar por Service. Útil cuando:

- No hay Service (jobs, workers headless).
- Quieres scrapear un sidecar en Pods de un Deployment aunque el Service no lo exponga.

### 4.3 `Probe`

Para **blackbox monitoring**: pide al `blackbox_exporter` que ejecute probes HTTP/TCP/ICMP contra URLs externas.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: Probe
metadata:
  name: external-apis
spec:
  jobName: http-probe
  prober:
    url: blackbox-exporter.monitoring.svc:9115
  module: http_2xx
  targets:
    staticConfig:
      static: [https://api.example.com/health]
```

### 4.4 `ScrapeConfig` (GA desde Operator v0.65+, GA real en v0.74)

Escapatoria para casos que las abstracciones anteriores no cubren: EC2 SD, Consul SD, HTTP SD, ficheros `file_sd`. Es *literalmente* un `scrape_config` nativo embebido en un CR.

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: ScrapeConfig
metadata:
  name: ec2-nodes
spec:
  ec2SDConfigs:
    - region: us-east-1
      port: 9100
```

**Cuándo elegir cada uno**: ServiceMonitor por default; PodMonitor si no hay Service; Probe para blackbox; ScrapeConfig solo si lo anterior no te alcanza.

---

## 5. CRDs de reglas y routing: `PrometheusRule`, `AlertmanagerConfig`

### 5.1 `PrometheusRule`

Equivalente al fichero `rules.yml` tradicional. Agrupa recording + alerting rules.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: fastapi-slo
  labels:
    release: kps          # ← ver §6
spec:
  groups:
    - name: fastapi.rules
      rules:
        - record: job:fastapi_requests:rate5m
          expr: sum by (job) (rate(http_requests_total[5m]))
        - alert: FastAPIErrorBudgetBurn
          expr: |
            sum(rate(http_requests_total{status=~"5.."}[5m]))
              / sum(rate(http_requests_total[5m])) > 0.02
          for: 10m
          labels:
            severity: critical
          annotations:
            summary: "FastAPI quema > 2% error budget 5m"
            runbook_url: "https://runbooks.example.com/fastapi-5xx"
```

El Operator junta todos los `PrometheusRule` que pasen el selector, los valida con `promtool`, y los monta en el Pod Prometheus.

### 5.2 `AlertmanagerConfig`

Permite ruteo por tenant/namespace sin tocar el `alertmanager.yml` global.

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: team-payments
  namespace: payments
spec:
  route:
    receiver: payments-pager
    groupBy: [alertname, namespace]
    routes:
      - matchers: [{name: severity, value: critical}]
        receiver: payments-pager
      - matchers: [{name: severity, value: warning}]
        receiver: payments-slack
  receivers:
    - name: payments-pager
      pagerdutyConfigs:
        - routingKey:
            name: pd-key
            key: integration-key
    - name: payments-slack
      slackConfigs:
        - apiURL: {name: slack-webhook, key: url}
          channel: "#payments-warn"
```

Debajo, el Operator genera un `alertmanager.yml` global que combina la ruta "root" del `Alertmanager` CR con subrutas por namespace.

---

## 6. Selectors: el error #1

**Este es el bug que más tiempo roba.** Un estudiante crea un `ServiceMonitor` precioso, lo aplica, mira `/service-discovery` y no aparece. Causa casi siempre: **el `Prometheus` CR tiene un selector que su ServiceMonitor no cumple**.

El `Prometheus` CR trae por default (en KPS):

```yaml
spec:
  serviceMonitorSelector:
    matchLabels:
      release: kps              # si instalaste con --release-name=kps
  serviceMonitorNamespaceSelector: {}   # todos los namespaces
  podMonitorSelector:
    matchLabels:
      release: kps
  ruleSelector:
    matchLabels:
      release: kps
```

Significa: el Operator solo recoge CRs que tengan la label `release: kps`. Si tu ServiceMonitor no la tiene, es ignorado — **sin error**, sin log evidente.

Hay tres soluciones:

1. **Añadir la label** a cada CR (lo más común y recomendado).
2. **Vaciar el selector** del Prometheus CR (`serviceMonitorSelector: {}`), que recoge *todo*. Útil en dev; peligroso en multi-tenant.
3. **Multiple Prometheus**: un `Prometheus` por tenant/equipo con selectors propios (§10).

Checks de diagnóstico:

```bash
# ¿El CR existe?
kubectl get servicemonitor -A

# ¿Qué labels tiene?
kubectl get servicemonitor fastapi-app -o jsonpath='{.metadata.labels}'

# ¿Qué selector pide el Prometheus?
kubectl get prometheus -A -o jsonpath='{.items[*].spec.serviceMonitorSelector}'

# ¿Aparece en el prometheus.yml generado?
kubectl -n monitoring get secret prometheus-kps-kube-prometheus-stack-prometheus \
  -o jsonpath='{.data.prometheus\.yaml\.gz}' | base64 -d | gunzip | grep -A5 fastapi-app
```

---

## 7. `kubernetes-mixin`: dashboards y alertas de serie

El proyecto [`kubernetes-mixin`](https://github.com/kubernetes-monitoring/kubernetes-mixin) es un conjunto *jsonnet* de dashboards y alertas mantenido por SIG-Instrumentation y usado por casi todos los stacks derivados. KPS lo pre-renderiza y lo incluye como:

- ~40 **dashboards** Grafana (API server, scheduler, kubelet, workloads, nodes, PVs, StatefulSets, networking).
- ~70 **alertas** `PrometheusRule` (p. ej. `KubePodCrashLooping`, `KubeNodeNotReady`, `KubeAPIDown`, `KubeletTooManyPods`, `NodeFilesystemAlmostOutOfSpace`).

Dos consecuencias prácticas:

1. **No reinventes dashboards** de K8s básico — ya existen y están bien.
2. Si quieres **silenciar** una alerta que no te sirve, no borres el fichero: haz override en los values del chart (`defaultRules.disabled.<nombre>: true`) o rutea a `/dev/null` desde AlertmanagerConfig.

---

## 8. Dashboards as code: ConfigMap con `grafana_dashboard=1`

Grafana en KPS corre con un **sidecar `k8s-sidecar`** que vigila ConfigMaps en el cluster y, si tienen una label determinada, los copia al filesystem de Grafana (`/tmp/dashboards/`), que a su vez los carga por provisioning.

Por default la label es `grafana_dashboard=1`. Esto hace que un dashboard JSON exportado pueda convertirse en ConfigMap:

```bash
kubectl -n monitoring create configmap my-dashboard \
  --from-file=my-dashboard.json \
  --dry-run=client -o yaml \
  | kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml \
  | kubectl apply -f -
```

Patrón GitOps:

```
dashboards/
  my-service.json
  k8s/
    workloads.json
dashboards.yaml      # kustomization que convierte cada .json en ConfigMap
```

Argo CD lo aplica y Grafana recoge los dashboards sin reinicio. Ventajas: versionado, revisión en PR, no hay "dashboard huérfano hecho a mano".

---

## 9. GitOps con Argo CD

Patrón recomendado:

```
observability/
├── argo-apps.yaml                 # Application de nivel 2 (app-of-apps)
├── kube-prometheus-stack/
│   ├── Chart.yaml                 # umbrella que depende de kube-prometheus-stack
│   └── values.yaml
├── crds/                          # ServiceMonitors, PrometheusRules, AlertmanagerConfigs
│   └── fastapi-sm.yaml
└── dashboards/
    └── fastapi.json → ConfigMap
```

Consideraciones:

- **CRDs**: KPS incluye los CRDs. Argo CD los instala la primera vez. Pero `helm upgrade` **no los actualiza** (§11). En Argo CD, usa `syncOptions: [ServerSideApply=true, Replace=true]` para los CRs del Operator con cuidado.
- **Pruning**: Argo CD puede borrar un `ServiceMonitor` si lo quitas del repo — exactamente lo que quieres.
- **Diff drift**: Argo marca drift si alguien edita un CR a mano. Esto es feature, no bug.
- **Dashboards**: como ConfigMap con label (§8). Argo los sincroniza.

Anti-pattern frecuente: tener el chart KPS en un repo *y* dashboards hechos a mano en Grafana UI. Elige uno; mezclar lleva a drift permanente.

---

## 10. Multi-tenant

Patrones comunes:

### 10.1 Un Prometheus por tenant

```yaml
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: payments
  namespace: payments-monitoring
spec:
  serviceMonitorSelector:
    matchLabels:
      tenant: payments
  serviceMonitorNamespaceSelector:
    matchLabels:
      tenant: payments
  ruleSelector:
    matchLabels:
      tenant: payments
  resources:
    requests: {memory: 2Gi}
```

Cada tenant tiene su Prometheus, sus retention, sus límites. Costoso en recursos pero aísla ruido y permisos.

### 10.2 Un Prometheus central con selectors por namespace

Más barato: un solo Prometheus que recoge *todo*, pero con labels obligatorias (`team=`, `tenant=`) para separar por dashboards/alertas.

### 10.3 `prometheusSelector` en el Alertmanager CR

Si tienes múltiples Prometheus que mandan al mismo Alertmanager, puedes filtrar.

Regla práctica: empieza con **monotenant** y migra a multi-tenant **solo** cuando aparecen conflictos reales de ruido, retention, o permisos. Multi-tenant precoz es sobre-ingeniería.

---

## 11. Upgrade seguro del stack

El dolor conocido: `helm upgrade` **no** reaplica los CRDs. Por diseño: podría destruir CRs existentes y perder datos. Para un upgrade correcto:

```bash
# 1. Mirar el CHANGELOG del chart (breaking changes de values).
helm show chart prometheus-community/kube-prometheus-stack | less

# 2. Actualizar los CRDs manualmente (desde la nueva versión del chart).
VERSION=60.0.0
kubectl apply --server-side -f \
  "https://raw.githubusercontent.com/prometheus-community/helm-charts/kube-prometheus-stack-${VERSION}/charts/kube-prometheus-stack/charts/crds/crds/"

# 3. Dry-run del upgrade.
helm upgrade kps prometheus-community/kube-prometheus-stack \
  -n monitoring --version "$VERSION" -f values.yaml --dry-run

# 4. Upgrade real.
helm upgrade kps prometheus-community/kube-prometheus-stack \
  -n monitoring --version "$VERSION" -f values.yaml

# 5. Verificar.
kubectl -n monitoring rollout status statefulset/prometheus-kps-kube-prometheus-stack-prometheus
kubectl -n monitoring rollout status statefulset/alertmanager-kps-kube-prometheus-stack-alertmanager
```

Checklist adicional:

- **Snapshot TSDB** si vas a saltar major versions.
- **Diff values**: `helm diff upgrade` (plugin) ayuda muchísimo.
- **Degradación**: `helm rollback kps <revision>` funciona para el chart, pero no revierte cambios de CRDs.

---

## 12. Troubleshooting operativo

El set mínimo:

```bash
# ¿Operator sano?
kubectl -n monitoring get deploy kps-kube-prometheus-stack-operator
kubectl -n monitoring logs deploy/kps-kube-prometheus-stack-operator --tail=100

# ¿Prometheus sano?
kubectl -n monitoring get prometheus
kubectl -n monitoring describe prometheus kps-kube-prometheus-stack-prometheus

# ¿CRs recogidos?
kubectl -n monitoring get servicemonitor,podmonitor,probe,prometheusrule -A

# ¿Qué entró al prometheus.yml generado?
kubectl -n monitoring get secret prometheus-kps-kube-prometheus-stack-prometheus \
  -o jsonpath='{.data.prometheus\.yaml\.gz}' | base64 -d | gunzip > /tmp/prom.yml
grep -A2 'job_name' /tmp/prom.yml

# UI port-forward
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090
#  → http://localhost:9090/service-discovery, /targets, /config, /rules
```

Checklist "mi ServiceMonitor no aparece":

1. ¿Labels del ServiceMonitor cumplen `serviceMonitorSelector` del Prometheus CR? (§6)
2. ¿`spec.selector` del ServiceMonitor coincide con las labels del Service? (`kubectl get svc <s> --show-labels`).
3. ¿`endpoints[].port` apunta al **nombre** del port del Service, no al número?
4. ¿El Service **tiene endpoints**? (`kubectl get endpoints <s>` — si está vacío, el Pod no está listo o el selector del Service falla).
5. ¿El `namespaceSelector` del ServiceMonitor cubre el namespace donde vive el Service?

"Golden signals" del propio stack:

- `up` por job (si tu stack scrapea 100 jobs y 5 están `up=0`, lo ves inmediatamente).
- `prometheus_tsdb_head_samples_appended_total` — write throughput.
- `prometheus_notifications_dropped_total` — Alertmanager mal integrado.
- `prometheus_config_last_reload_successful` — si está en 0, el `prometheus.yml` generado tiene error de sintaxis.

Si lo último sale en 0: `kubectl -n monitoring logs sts/prometheus-kps-kube-prometheus-stack-prometheus -c prometheus` suele dar el mensaje exacto del parser.
