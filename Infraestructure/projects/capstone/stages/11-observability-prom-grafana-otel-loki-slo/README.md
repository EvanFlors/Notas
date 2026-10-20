# Capstone — Etapa 11: Observabilidad (Prometheus + Grafana + OTel + Loki + Tempo + SLO)

> Fase 5 del programa · Dominio tocado: D10 (observabilidad, SRE, SLOs).
> Stack fijado: **kube-prometheus-stack + Grafana + OpenTelemetry Collector + Loki + Tempo**, sobre el cluster que ya existe desde la Etapa 8/9/10 (GitOps con Argo CD + Argo Rollouts).
> Esta etapa es **cluster-interno** (`local-first` sobre `kind` o `cloud-permitido` sobre EKS/GKE/AKS). No añade recursos externos facturables más allá del propio nodo pool.

---

## 1. Resumen de la etapa

**Objetivo.** Dejar la plataforma observable end-to-end sobre los tres pilares (métricas, logs, trazas) y gobernada por un SLO formal del `99.9 %` de disponibilidad, con alertas de burn-rate **MWMBR** (Multi-Window Multi-Burn-Rate) que paginan rápido cuando el error budget se consume agresivamente y lentamente cuando se agota de forma crónica.

**Delta vs. Etapa 10.** La 10 dejó Argo CD + Argo Rollouts promoviendo cambios con buena higiene de GitOps, pero sin señales confiables para decidir si "lo que acabo de promover está bien". Esta etapa provee **esas señales** y las ancla a un objetivo numérico (`SLO`).

- `+` `kube-prometheus-stack` (Prometheus Operator, Alertmanager, node-exporter, kube-state-metrics, Grafana base).
- `+` `ServiceMonitor` que scrapea el `/metrics` de FastAPI (expuesto vía `prometheus-fastapi-instrumentator`).
- `+` `PrometheusRule` con las SLIs (`http_requests_total`, `http_requests_total{status=~"5.."}`), el SLO y las 4 alertas MWMBR.
- `+` **OpenTelemetry Collector** desplegado en dos capas: un **agent** (DaemonSet) por nodo + un **gateway** (Deployment) central.
- `+` Loki (logs) y Tempo (trazas) exponiendo backends; FastAPI envía trazas vía OTLP al agent.
- `+` Dashboards de Grafana con **Golden Signals** (latencia, tráfico, errores, saturación) y uno dedicado al **error budget**.
- `+` `app/instrumentation.py` que inicializa el SDK de OTel (tracer + propagators + resource) una sola vez.

**Fuera de scope (futuras etapas).**

- Logs con pipeline de parseo complejo o PII masking → se cubre con un `OpenTelemetry Transform Processor` dedicado más adelante.
- Alertas en PagerDuty/Opsgenie reales → aquí sólo configuramos un `webhook.site` o `null` receiver didáctico.
- Perfiles / continuous profiling (Pyroscope) → fuera de esta etapa.
- Tail-based sampling en el collector → la Etapa 11 usa *head-based parent-based* al `10 %`; sampling avanzado llega después.
- SLOs multi-servicio (burning rate por tenant) → se discute en la etapa de Platform Engineering.

---

## 2. Arquitectura al cierre de esta etapa

```
                       +--------------------------------------------------------+
                       |                         Cluster K8s                     |
                       |                                                         |
   usuario ---HTTP---> |  Ingress --> Service (FastAPI, Rollouts canary)         |
                       |                      |                                  |
                       |                      | (1) /metrics  (2) OTLP           |
                       |                      v                                  |
                       |             +----------------+     OTLP     +---------+ |
                       |             |  FastAPI pod   |------------->| OTel    | |
                       |             |  app + sidecar |              | agent   | |
                       |             |  instrumented  |              | (DS)    | |
                       |             +----------------+              +----+----+ |
                       |                      ^                           |      |
                       |         scrape /metrics                          |      |
                       |                      |                           v OTLP |
                       |             +--------+--------+          +---------+    |
                       |             |  Prometheus     |          |  OTel   |    |
                       |             |  (kube-prom)    |          | gateway |    |
                       |             +----+-------+----+          +----+----+    |
                       |                  |       | remote-write?      |         |
                       |          rules   |       |                    v         |
                       |                  v       |             +------+-----+   |
                       |          +---------+     |             |   Tempo    |   |
                       |          | Alert   |     |             +------+-----+   |
                       |          | manager |     |                    |         |
                       |          +----+----+     |             +------+-----+   |
                       |               | webhook  |             |   Loki     |   |
                       |               v          |             +------+-----+   |
                       |          webhook.site    |                    |         |
                       |                          v                    v         |
                       |                     +----------------------------+      |
                       |                     |          Grafana           |      |
                       |                     |  (Prom + Loki + Tempo DS)  |      |
                       |                     +----------------------------+      |
                       +--------------------------------------------------------+
```

**Entradas.** Peticiones HTTP a FastAPI; traces y logs se originan dentro de la app vía OTel SDK; métricas por el endpoint `/metrics`.
**Salidas.** Series de tiempo en Prometheus, logs en Loki, spans en Tempo, dashboards y alertas en Grafana/Alertmanager.
**Resource list.** `kube-prometheus-stack`, `opentelemetry-collector` (DaemonSet + Deployment), `loki` (SingleBinary), `tempo` (SingleBinary), `grafana` (viene con el stack), 3 `Namespace` (`observability`, `tracing`, `logging` — o uno solo `observability` según gusto).

---

## 3. Prerrequisitos verificados

- [ ] Etapas 1-10 cerradas (app, CI, container, IaC, cloud, k8s, Helm, Argo CD, Rollouts).
- [ ] `kubectl` apunta al cluster correcto (`kubectl config current-context`).
- [ ] `helm` >= 3.14 instalado.
- [ ] `yq` >= 4 instalado (para validar YAML).
- [ ] Opcional: `promtool` y `amtool` para validar reglas/receivers localmente (si faltan, el `validate.sh` lo detecta y hace SKIP, no FAIL).
- [ ] Opcional: `jq` para parsear la salida de `kubectl` en los *drills*.
- [ ] `app/` del capstone exporta `/metrics` (añadido en la Etapa 3) y escucha OTLP (lo añadimos aquí vía `app/instrumentation.py`).

Si falta algo, cierra ese hueco primero: ninguna de las herramientas requiere credenciales en la nube, se instalan con `brew`, `asdf` o binario estático.

---

## 4. Implementación guiada

Los artefactos viven bajo `observability/`. El flujo es: instalar operadores con Helm, aplicar los CR (`ServiceMonitor`, `PrometheusRule`), importar dashboards, instrumentar la app.

### 4.1 Instalar `kube-prometheus-stack`

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  --namespace observability \
  -f observability/kube-prometheus-stack-values.yaml \
  --version 65.0.0
```

**Por qué el Operator y no Prometheus "pelado":** porque reconcilia `ServiceMonitor`/`PodMonitor`/`PrometheusRule` como CRDs, lo que te permite versionar la configuración de scraping junto al servicio (y hace que Argo CD la gestione como cualquier otro manifest).

**Por qué `65.0.0`:** rama estable al cierre de esta etapa (Prometheus 2.54, Grafana 11.x). Si usas una versión más nueva, confirma que los CRDs no cambiaron de API group.

### 4.2 Aplicar el `ServiceMonitor` + la `PrometheusRule`

```bash
kubectl apply -f observability/servicemonitor.yaml
kubectl apply -f observability/prometheusrule-slo.yaml
```

**Por qué separados del chart:** quedan como artefactos propios del servicio FastAPI, no del chart del operator. Esto habilita que vivan al lado del chart de la app en el repo GitOps (Etapa 9) sin acoplarse al release del operator.

### 4.3 Instalar el OpenTelemetry Collector (agent + gateway)

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm upgrade --install otel-agent open-telemetry/opentelemetry-collector \
  --namespace observability \
  -f observability/otel-collector-values.yaml \
  --set mode=daemonset \
  --version 0.100.0

helm upgrade --install otel-gateway open-telemetry/opentelemetry-collector \
  --namespace observability \
  -f observability/otel-collector-values.yaml \
  --set mode=deployment \
  --version 0.100.0
```

**Por qué agent + gateway:** el agent (DaemonSet) recibe telemetría local del nodo con latencia mínima y sin saltar red; el gateway (Deployment) centraliza colas, retries, batching y es el único que habla con los backends (Loki/Tempo), lo que te deja un único choke-point para aplicar sampling o PII masking.

### 4.4 Instalar Loki y Tempo

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install loki grafana/loki \
  --namespace observability \
  -f observability/loki-values.yaml \
  --version 6.10.0

helm upgrade --install tempo grafana/tempo \
  --namespace observability \
  -f observability/tempo-values.yaml \
  --version 1.10.0
```

**Por qué SingleBinary y no microservicios:** el modo monolítico es más que suficiente para el volumen del capstone (<10 req/s), y evita tener que operar Memcached + Ingesters + Queriers por separado. Si en producción creces, migras a microservicios cambiando `deploymentMode: SingleBinary` → `Distributed`.

### 4.5 Importar el dashboard de Golden Signals en Grafana

Dos opciones (elige una):

- Vía UI: `Dashboards -> Import -> Upload JSON` subiendo `observability/grafana-dashboards/fastapi-golden-signals.json`.
- Vía sidecar: añade la ConfigMap con la label `grafana_dashboard=1` y el sidecar de Grafana la recoge automáticamente (recomendado para GitOps).

### 4.6 Instrumentar la app

Añade al `main.py` de FastAPI al inicio:

```python
from app.instrumentation import init_telemetry
init_telemetry(service_name="capstone-api")
```

El SDK envía trazas por OTLP al agent en `http://otel-agent.observability.svc:4317`. Las métricas siguen siendo pull-based vía `prometheus-fastapi-instrumentator`.

**Por qué un módulo dedicado `app/instrumentation.py`:** aisla la configuración de OTel del código de producto, lo hace idempotente (`init_telemetry` chequea si ya hay un `TracerProvider` global) y permite testear la configuración sin levantar la app entera.

### 4.7 SLO y burn-rate (MWMBR)

El SLO declara `99.9 %` de disponibilidad medido como `1 - (5xx / total)` sobre todas las rutas excepto `/metrics` y `/healthz` (que distorsionan el denominador). El error budget es `0.1 %` = ~43 min/mes.

Las 4 alertas MWMBR implementan el patrón del Google SRE workbook (capítulo *Alerting on SLOs*):

| Severidad | Ventana corta | Ventana larga | Burn-rate | Significado |
|-----------|---------------|---------------|-----------|-------------|
| `page`    | 5m            | 1h            | 14.4      | A ese ritmo gastas el budget del mes en 2h. |
| `page`    | 30m           | 6h            | 6         | Agotas el budget del mes en 5h. |
| `ticket`  | 2h            | 24h           | 3         | Agotas el budget del mes en 10h. |
| `ticket`  | 6h            | 72h           | 1         | Agotas el budget del mes justo en 30d. |

**Por qué ventana corta + larga en AND:** la corta minimiza *time-to-detect*; la larga filtra falsos positivos de picos brevísimos. Sólo si ambas superan el umbral, se dispara.

---

## 5. Actividades del estudiante

Vive bajo `activities/`.

| ID activity | Tipo | Tiempo | Objetivo |
|---|---|---|---|
| `cap-11-01-wire-slo-burn-rate-alerts` | independent | 70 min | Validar manifiestos (`promtool`/`amtool` si están, YAML parse si no), inyectar un error 500 sintético y confirmar que la alerta `HighErrorBudgetBurnFast` entra en estado `firing` dentro de 5 min. |

Si quieres sumar `guided-lab` o `debug` adicionales, añádelas con la misma convención (`cap-11-NN-slug`).

---

## 6. Entregables

- `observability/kube-prometheus-stack-values.yaml` versionado.
- `observability/servicemonitor.yaml` y `observability/prometheusrule-slo.yaml` aplicados y verdes en `kubectl get prometheusrule -o yaml`.
- `observability/grafana-dashboards/fastapi-golden-signals.json` cargado y mostrando datos reales.
- `observability/otel-collector-values.yaml` con agent + gateway desplegados.
- `observability/loki-values.yaml` y `observability/tempo-values.yaml` desplegados y configurados como datasources en Grafana.
- `app/instrumentation.py` referenciado desde `main.py`.
- `activities/01-wire-slo-burn-rate-alerts/` con `validate.sh` en verde.
- Captura o export de dashboard con los 4 Golden Signals + panel de error budget restante.

---

## 7. Pruebas y criterios de aceptación

**Chequeos automáticos (los corre `tests/validate.sh`):**

- [ ] Los 7 manifiestos / values parsean como YAML y no están vacíos.
- [ ] `promtool check rules observability/prometheusrule-slo.yaml` sale 0 (o SKIP si falta la herramienta).
- [ ] `amtool check-config` sobre el fragmento de Alertmanager en el values del operator (o SKIP).
- [ ] `app/instrumentation.py` compila con `python -m py_compile` (si Python está disponible, si no SKIP).
- [ ] El dashboard JSON es parseable como JSON y declara al menos los 4 paneles (latencia, tráfico, errores, saturación).
- [ ] La `PrometheusRule` declara las 4 alertas MWMBR por nombre.

**Criterios de calidad:**

- [ ] Dashboards versionados en git, no sólo en Grafana.
- [ ] Alertas incluyen `runbook_url` en las annotations.
- [ ] Nada de secretos reales (los `remoteWrite`, `basic_auth`, tokens son `dummy_*`).
- [ ] El OTel Collector corre en dos modos (DS y Deploy) con pipelines separados por señal.
- [ ] Spam de alertas controlado: `group_wait: 30s`, `repeat_interval: 4h`.

---

## 8. Costos y limpieza

**Costo cloud (si `cloud-permitido`).** Depende del cluster subyacente de la Etapa 7/8. Los stacks de observabilidad añaden ~2 vCPU y ~4 GiB de RAM; en un EKS t3.medium es ~$0.05/h extra = ~$36/mes. En `kind` local el costo es $0.

**Limpieza:**

```bash
helm uninstall tempo loki otel-gateway otel-agent kps -n observability
kubectl delete namespace observability
kubectl delete prometheusrule --all -A
kubectl delete servicemonitor --all -A
```

Las CRDs del operator **no** se borran al desinstalar el chart (es intencional). Para quitarlas:

```bash
kubectl get crd -o name | grep -E 'monitoring\.coreos\.com|opentelemetry\.io' | xargs kubectl delete
```

---

## 9. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Prometheus se queda sin disco por retención agresiva. | `prometheusSpec.retention: 10d` y `storageSpec: 10Gi`; alerta `PrometheusDiskUsageHigh` incluida. |
| El SLO queda "verde" porque el denominador incluye `/metrics` + `/healthz`. | La expresión del SLI excluye explícitamente esas rutas con `handler!~"/metrics|/healthz"`. |
| El OTel agent sobrecarga el nodo si cada pod envía trazas sin sampling. | `tail_sampling` no, pero sí `probabilistic_sampler` al 10 % en el gateway (`sampling_percentage: 10`). |
| Las dashboards no sobreviven a reinstalar Grafana. | Dashboards como `ConfigMap` con label `grafana_dashboard=1` → sidecar los re-importa en cada boot. |

**Hints progresivos:**

1. ¿La alerta no dispara? `kubectl get prometheusrule -n observability -o yaml` y confirma que el operator la montó dentro del Prometheus pod.
2. ¿Loki vacío? Mira si el OTel gateway tiene `exporters.loki.endpoint` apuntando al Service correcto (`http://loki.observability.svc:3100/loki/api/v1/push`).
3. ¿Tempo no muestra trazas? Verifica que `OTEL_EXPORTER_OTLP_ENDPOINT` en los pods de FastAPI apunta al agent del mismo nodo (vía `status.hostIP`).

---

## 10. Puente con la siguiente etapa

**Qué habilita esta etapa.** La Etapa 12 (DevSecOps completo con ESO + Kyverno + Falco + Policy as Code) asume que ya puedes **ver** cuándo una policy bloquea algo (Falco → Loki → Grafana) y que el SLO sirve de termómetro: si una policy demasiado estricta sube el error-rate, la alerta `HighErrorBudgetBurnFast` te avisa antes del postmortem.

**Qué dejamos corriendo.** Todo el stack de observabilidad. Es la base de todo lo que viene después (DevSecOps, Platform Engineering, Load testing, DR). Apagarlo rompe el contrato de la Restricción #5 del Prompt 10.

**Cliffhanger.** Ya sabes **cuándo** algo va mal (`SLO` ardiendo). ¿Y cómo garantizas que lo que estás desplegando no viola políticas de seguridad **antes** de que llegue al cluster? ¿Y qué pasa si un atacante intenta cambiar un pod en caliente? Esa es la Etapa 12.
