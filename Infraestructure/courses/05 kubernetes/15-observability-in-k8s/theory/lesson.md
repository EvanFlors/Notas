# Lección: Observabilidad en Kubernetes

> **ID:** `k8s-15-observability-in-k8s` · **Nivel:** producción · **Duración:** 6 h
> **Prerrequisitos:** `k8s-14`.

---

## 1. Introducción intuitiva

Son las 03:47. Un dashboard muestra que la latencia P99 del checkout subió a 4 s. Tienes tres preguntas:

1. **¿Es grande el problema?** (SLO: ¿quemamos presupuesto de error?).
2. **¿Dónde está el cuello?** (métricas por servicio, por endpoint, por pod).
3. **¿Qué cambió?** (deploy reciente, cambio de config, pico de tráfico, nodo caído).

Sin observabilidad, respondes esto mirando logs sueltos y adivinando. Con observabilidad, respondes en minutos: un **dashboard** te dice que la P99 de `checkout` subió solo en el servicio `payments`; un **trace** te muestra que el 90% del tiempo se lo come un `POST` al proveedor externo; una **métrica** del operador de red Cilium (eBPF) te muestra retransmisiones TCP a su CIDR; un **evento** de K8s te confirma que un nodo entró en `NotReady` hace 6 minutos.

Observabilidad **no es tener Grafana instalado**. Es **poder responder preguntas que aún no imaginaste** sobre el comportamiento de tu sistema, usando los datos que ya emite.

Las **tres señales clásicas** (metrics, logs, traces) son herramientas distintas con costos distintos:

| Señal | Qué pregunta responde | Costo típico |
|-------|----------------------|--------------|
| Metrics | "¿Cuánto?" (QPS, latencia, errores) | bajo (series TS numéricas) |
| Logs | "¿Qué pasó?" (eventos textuales) | alto (texto, cardinality) |
| Traces | "¿Dónde se fue el tiempo?" (por request) | medio (sampling) |

En Kubernetes se añade una cuarta: **Events** (`kubectl events`) — baratos y críticos para debugging del control plane.

---

## 2. Fundamentos

### 2.1 Los dos sistemas de métricas en K8s

Mucha confusión viene de aquí. Kubernetes tiene **dos** APIs de métricas:

```
┌─────────────────────────────────────────────────────────────────┐
│ metrics.k8s.io  (resource metrics API)                          │
│   - CPU y memoria por Pod/Node, agregadas, "ahora"              │
│   - Fuente: cAdvisor en kubelet → agregado por metrics-server   │
│   - Consumidor: HPA v1, VPA, 'kubectl top'                      │
│   - NO para alerting, NO histórico, NO dimensional              │
├─────────────────────────────────────────────────────────────────┤
│ custom.metrics.k8s.io / external.metrics.k8s.io                 │
│   - Métricas arbitrarias para HPA v2 (y afines)                 │
│   - Fuente: prometheus-adapter o KEDA, leyendo Prometheus       │
│                                                                  │
│ + Prometheus (fuera del API de K8s)                             │
│   - Series TS multidimensionales, histórico, alerting           │
│   - Fuente: scrape pull de endpoints /metrics                   │
│   - Consumidor: Grafana, Alertmanager, prometheus-adapter       │
└─────────────────────────────────────────────────────────────────┘
```

**Regla**: `metrics-server` es el "termómetro para el momento actual" del scheduler/HPA; Prometheus es el "sistema de observabilidad". No son alternativas, son capas distintas.

### 2.2 Fuentes de métricas en un cluster

- **cAdvisor** — ya está dentro del `kubelet`. Expone métricas de containers (CPU, memoria, red, IO) en `/metrics/cadvisor` del kubelet. No se instala.
- **kubelet** — además expone sus propias métricas en `/metrics` y `/metrics/resource` (resource metrics v1alpha1 → feeds a metrics-server).
- **metrics-server** — agrega lo anterior y lo publica como `metrics.k8s.io`.
- **kube-state-metrics (KSM)** — **no** mide recursos. Convierte el *estado* del API (Deployments, Pods, Jobs, etc.) en métricas. Ejemplos: `kube_deployment_status_replicas_available`, `kube_pod_container_status_restarts_total`, `kube_job_status_failed`.
- **node-exporter** — métricas del host Linux (filesystem, CPU por CPU, loadavg, kernel, net). DaemonSet.
- **Apps propias** — exponen `/metrics` (text/plain Prometheus format o OpenMetrics) y Prometheus las scrapea.
- **control plane** — apiserver, scheduler, controller-manager, etcd exponen métricas Prometheus-native en sus endpoints internos.

### 2.3 Diagrama del stack típico

```
          ┌─────────────┐
          │   Grafana   │  dashboards + explore (metrics, logs, traces)
          └─────┬───────┘
                │ Prometheus · Loki · Tempo datasources
                │
   ┌────────────┼────────────────────────────────────┐
   │            │                                    │
┌──▼──────┐  ┌──▼──────┐    ┌───────────┐    ┌──────▼───────┐
│Prometheus│  │  Loki   │    │   Tempo   │    │ Alertmanager │
│ (TSDB)   │  │ (logs)  │    │ (traces)  │    │  (routing)   │
└──┬───────┘  └──▲──────┘    └──▲────────┘    └──────────────┘
   │ scrape pull │ push         │ push OTLP
   │             │              │
┌──┴─────────────┴──────────────┴──────────────────────────┐
│ ServiceMonitor/PodMonitor   DaemonSet shipper   OTel SDK │
│  (CRs del Operator)         (Promtail/Vector/   en apps  │
│                              OTel Collector)             │
├──────────────────────────────────────────────────────────┤
│  app /metrics  ·  cAdvisor  ·  kube-state-metrics       │
│  node-exporter ·  apiserver /metrics ·  kubelet /metrics│
└──────────────────────────────────────────────────────────┘
```

---

## 3. Prometheus Operator y sus CRDs

Instalar Prometheus "a mano" en K8s es tedioso: configurar `prometheus.yml` para cada Service, actualizarlo cada vez que aparece uno nuevo, montar reglas como ConfigMap, recargar... El **Prometheus Operator** (CoreOS/RedHat, hoy en CNCF) lo resuelve con CRDs:

| CR | Qué representa |
|----|---------------|
| `Prometheus` | Instancia(s) de Prometheus desplegadas por el operator. |
| `Alertmanager` | Instancia(s) de Alertmanager. |
| `ThanosRuler` | Instancia(s) de reglas Thanos (opcional). |
| `ServiceMonitor` | "Scrapea los endpoints de los Services que matchean este selector". |
| `PodMonitor` | "Scrapea los Pods que matchean (sin pasar por Service)". |
| `Probe` | Blackbox-exporter: pingea URLs externas o internas. |
| `PrometheusRule` | Reglas (recording + alerting) montadas automáticamente. |
| `AlertmanagerConfig` | Routing y receivers por namespace (RBAC-friendly). |

### 3.1 Cómo descubre un `ServiceMonitor`

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: fastapi-app
  namespace: apps
  labels:
    release: kube-prometheus-stack   # requerido por el Prometheus para "adoptarlo"
spec:
  selector:
    matchLabels:
      app: fastapi
  namespaceSelector:
    matchNames: [apps]
  endpoints:
    - port: http            # nombre del puerto del Service
      path: /metrics
      interval: 30s
```

**Lo que ocurre internamente** (importante entenderlo):

1. El operator observa `ServiceMonitor`.
2. Para cada Service que matchea `selector`, el operator genera un `scrape_config` en el `prometheus.yml` interno (en un Secret montado como fichero).
3. Prometheus recarga (o se reinicia) y empieza a scrapear.
4. El **endpoint** real es el EndpointSlice del Service (lista de Pods), **no** el ClusterIP: Prometheus scrapea cada Pod individualmente.

Un `ServiceMonitor` **no funciona** si:
- El Service no tiene un `port` con `name:` (hay que nombrarlo).
- El `release` label (u otro `serviceMonitorSelector` del CR `Prometheus`) no matchea.
- `namespaceSelector` deja fuera el namespace del Service.
- RBAC: Prometheus no tiene permiso `get/list/watch` sobre Services/Endpoints en el namespace.

### 3.2 `PodMonitor` vs `ServiceMonitor`

Usá `PodMonitor` cuando no hay Service (ej. Jobs, apps sin exposición de red clara). Usá `ServiceMonitor` cuando ya tenés Service: es más portable y la configuración vive más cerca del contrato ya definido para la app.

---

## 4. kube-prometheus-stack: el paquete "todo incluido"

El chart Helm **`kube-prometheus-stack`** (mantenido por la comunidad Prometheus) instala en un comando:

- Prometheus Operator + CRDs.
- Una instancia de Prometheus pre-configurada para scrapear el cluster.
- Alertmanager.
- `kube-state-metrics`.
- `node-exporter` (como DaemonSet).
- Grafana con datasources ya apuntando a Prometheus.
- Un set de **ServiceMonitors** para componentes del control plane y kubelet.
- Un set de **PrometheusRules** y dashboards del **kubernetes-mixin** (alertas y dashboards probados).

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --values values.yaml
```

Es un chart **grande** (muchos CRDs y manifests). En kind local requiere **al menos 4 GB** de RAM para el nodo y recursos de disco. Si no, considerá un stack ligero (solo Prometheus + Grafana + 1 app).

---

## 5. Logs: Loki, Promtail, Vector, OTel Collector

### 5.1 Por qué Loki

Loki (Grafana Labs) es "Prometheus para logs": **indexa solo labels**, no el contenido del log. El cuerpo del log se guarda comprimido en object storage. Consecuencia:

- **Costo bajo** vs Elasticsearch (que indexa todo).
- **Querying por labels** es ultra-rápido; `grep` en el contenido es más lento (lineal sobre el chunk).
- **No puedes hacer** facetas complejas sobre el texto como en ELK sin pagar en latencia.

Para la mayoría de workloads K8s (logs estructurados o semi-estructurados con labels útiles como `namespace`, `pod`, `app`, `container`), Loki es suficiente y 10x más barato.

### 5.2 Shippers

Loki no scrapea logs — necesita que algo se los **mande** (push). Opciones:

| Shipper | Lenguaje | Cuándo elegirlo |
|---------|---------|-----------------|
| **Promtail** | Go | Default histórico de Loki. Simple, DaemonSet, lee `/var/log/pods/*`. En mantenimiento pero soportado. |
| **Vector** (Datadog) | Rust | Alto rendimiento, pipelines más expresivos (VRL), puede escribir a muchos sinks. |
| **OpenTelemetry Collector** (receiver `filelog`) | Go | Elección estratégica si ya usas OTel para traces/metrics. Un solo agent para todo. |
| **Fluent Bit** / **Fluentd** | C / Ruby | Si ya los usabas antes; sanos y maduros. |

### 5.3 Patrón DaemonSet

Todos corren como DaemonSet: 1 Pod por nodo, montando `/var/log/pods` y `/var/log/containers` (symlinks que el kubelet mantiene). Esto evita que la app tenga que saber nada del logging — basta con escribir a `stdout`/`stderr`.

---

## 6. Traces: Tempo, Jaeger y OpenTelemetry

### 6.1 Modelo mental de trazas

Un **trace** es un árbol de **spans**. Cada span tiene `trace_id`, `span_id`, `parent_span_id`, nombre, tiempos, atributos. Correlar logs y métricas con traces exige que todas las señales lleven el `trace_id` o un identificador compartido (**exemplars** en Prometheus permiten eso).

### 6.2 Tempo vs Jaeger

| | **Tempo** | **Jaeger** |
|-|-----------|------------|
| Storage | object storage (S3/GCS/MinIO) | Cassandra, ES, ScyllaDB, Kafka |
| Query | TraceQL + Grafana | Jaeger UI (y Grafana) |
| Costo | bajo (object storage) | medio-alto |
| Sampling | tail-based opcional vía Collector | tail-based en remote sampling |

**Tempo** se diseñó para "trazas baratas, siempre on" (igual que Loki para logs). Si tu volumen de trazas es alto, Tempo con muestreo por *tail* en el Collector es la opción estándar hoy.

### 6.3 OpenTelemetry Operator

El **OTel Operator** aporta CRDs:

- `OpenTelemetryCollector` — despliega el Collector con el pipeline que vos definas (receivers, processors, exporters).
- `Instrumentation` — define **auto-instrumentación** por lenguaje (Java, Python, .NET, Node, Go). Se inyecta vía annotation en el Pod (`instrumentation.opentelemetry.io/inject-python: "true"`).

El Collector es el "pegamento": recibe OTLP (gRPC/HTTP) de las apps, puede transformar, muestrear y exportar a Tempo, Jaeger, Prometheus (via remote-write), Loki, OTLP gRPC remoto, etc.

---

## 7. Eventos de Kubernetes como señal

`kubectl events` muestra el stream de eventos del API: `BackOff`, `FailedScheduling`, `Killing`, `Evicted`, `NodeNotReady`, etc. Son **objetos K8s** (`corev1.Event`), con TTL (1 h por default).

**Problema**: son efímeros. Para análisis forense se necesita persistirlos. Dos patrones:

- **EventExporter** (`opsgenie/kubernetes-event-exporter` o `resmoio/kubernetes-event-exporter`): watchea el stream y lo envía a Loki, webhooks, Elasticsearch, OpenSearch.
- **Métricas derivadas**: `kube-state-metrics` ya expone `kube_pod_container_status_restarts_total` y afines; para contadores de eventos, hay exporters como `kube-eventer`.

Los eventos complementan métricas y logs — no los reemplazan. Un `OOMKilled` aparece como:

- **Evento**: `BackOff` + `Killing` en el Pod.
- **Métrica**: `kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}`.
- **Log**: la última línea de `stdout` antes del kill.

---

## 8. eBPF para observabilidad: Pixie y Hubble

### 8.1 Pixie (New Relic / CNCF sandbox)

Pixie instrumenta un cluster **sin cambiar código**: con **eBPF** engancha `read/write/connect/accept` a nivel kernel y reconstruye tráfico HTTP, gRPC, MySQL, PostgreSQL, DNS, Kafka, Redis. Expone un UI tipo notebook con PxL (Python-like) para consultar.

**Trade-off**: muy útil para debugging ad hoc y para apps sin instrumentar; no reemplaza a Prometheus/Tempo porque no persiste series ni traces (por default). Pensalo como "tcpdump con cerebro".

### 8.2 Hubble (Cilium)

Si tu CNI es Cilium (o lo puedes ser), **Hubble** da **observabilidad de red L3-L7** nativa: qué Pod habla con qué Pod, en qué puerto, con qué verdict (`FORWARDED`, `DROPPED` por NetworkPolicy, `ERROR`), y en L7 (HTTP) con método, path y status. Hubble Relay agrega todo el cluster, Hubble UI lo visualiza.

Para depurar NetworkPolicy, DNS failures o latencia por red, Hubble es imbatible y basado en eBPF (sin sidecars, sin instrumentar).

---

## 9. Alertas: señal vs ruido

### 9.1 El pecado capital: alertas sintomáticas sin umbral útil

```yaml
# ANTI-PATRÓN — no copies esto
- alert: HighCpuUsage
  expr: rate(container_cpu_usage_seconds_total[1m]) > 0.1
  for: 1m
  labels: { severity: warning }
  annotations: { summary: "CPU alta" }
```

Esto se dispara **todo el tiempo** (0.1 CPU-second/second es nada para muchas workloads) y, cuando se dispara en un problema real, el on-call ya aprendió a ignorarlo. **Fatiga de alerta** = cero valor de las alertas.

### 9.2 Reglas de oro

1. **Alerta sobre síntomas de usuario, no sobre causas** (preferible: SLO quemándose, no "CPU al 80%").
2. **Toda alerta debe ser accionable**: si el on-call no puede hacer nada ahora, no es una alerta — es un dashboard.
3. **Toda alerta debe tener runbook** (`annotations.runbook_url`).
4. **Toda alerta debe tener severidad clara** (`critical` = despertar; `warning` = horario laboral; `info` = log only).
5. **`for:` apropiado** — un pico de 10 s no es incidente; típicamente `for: 5m` o `10m` para evitar flapping.

### 9.3 SLO + burn-rate multi-window multi-burn-rate

El patrón canónico (Google SRE Workbook): si un SLO dice "99.9% de requests `OK` en 30 días" (presupuesto de error = 0.1%), definís **burn rate** como "a este ritmo, en cuánto quemás el presupuesto". Alertás cuando se **quema rápido** en una **ventana corta** **y** **lento** en una **ventana larga** (confirma que no es ruido).

Ejemplo (de la Mixin oficial, simplificado):

```yaml
groups:
- name: slo-availability
  rules:
  - record: slo:availability_errors:ratio_rate5m
    expr: sum(rate(http_requests_total{status=~"5.."}[5m]))
          / sum(rate(http_requests_total[5m]))
  - record: slo:availability_errors:ratio_rate1h
    expr: sum(rate(http_requests_total{status=~"5.."}[1h]))
          / sum(rate(http_requests_total[1h]))

  - alert: SLOErrorBudgetBurnFast
    expr: slo:availability_errors:ratio_rate5m > (14.4 * 0.001)
      and slo:availability_errors:ratio_rate1h > (14.4 * 0.001)
    for: 2m
    labels: { severity: critical }
    annotations:
      summary: "Quemando >14.4x del budget (fast burn)"
      runbook_url: "https://runbooks.example.com/slo-fast-burn"
  - alert: SLOErrorBudgetBurnSlow
    expr: slo:availability_errors:ratio_rate30m > (6 * 0.001)
      and slo:availability_errors:ratio_rate6h  > (6 * 0.001)
    for: 15m
    labels: { severity: warning }
    annotations:
      summary: "Quemando >6x del budget (slow burn)"
      runbook_url: "https://runbooks.example.com/slo-slow-burn"
```

Las constantes `14.4`, `6`, `1`, `0.1` provienen del Workbook SRE para un SLO 99.9% en 30 días. La idea clave: **doble ventana** = casi cero falsos positivos.

---

## 10. Dashboards: la mixin oficial y qué construir vos

### 10.1 kubernetes-mixin

<https://github.com/kubernetes-monitoring/kubernetes-mixin> es un conjunto de reglas Prometheus (`.libsonnet`) y dashboards Grafana que **ya traen**:

- Dashboards por rol: cluster, nodes, namespace, workload, pod, API server, controller-manager, scheduler, kubelet, networking (CoreDNS), persistent volumes.
- Alertas sanas: `KubePodCrashLooping`, `KubeDeploymentReplicasMismatch`, `KubeNodeNotReady`, `KubeAPIDown`, `KubeAggregatedAPIDown`, etc.

**`kube-prometheus-stack` las instala por default.** Antes de inventar un dashboard propio, chequeá si ya existe. La mixin la mantienen SIG-Instrumentation y la comunidad, con test harness.

### 10.2 El principio USE y RED

- **USE (Brendan Gregg, infra)**: para cada recurso → **Utilization, Saturation, Errors**. CPU, memoria, disco, red.
- **RED (Tom Wilkie, servicios)**: para cada servicio → **Rate, Errors, Duration**.

Un dashboard "sano" sigue USE para nodos/componentes y RED para apps.

---

## 11. Decisiones típicas

### 11.1 Retention vs costo

Prometheus local-storage es rápido pero no escala en retención larga (TB de series por mes es duro). Para retención > 15-30 días o para HA/multicluster, elegí:

- **Thanos** — sidecars o receiver, long-term en S3/GCS.
- **Cortex / Grafana Mimir** — Prometheus as a service, multi-tenant, TB-scale.
- **VictoriaMetrics** — alternativa de alta eficiencia, API-compatible.

Loki y Tempo ya nacen con object storage como primera clase.

### 11.2 Cardinality (el enemigo)

Una métrica `http_requests_total{method, status, path, user_id, trace_id}` **explota** la cardinalidad. Regla: cada label debe tener **conjunto acotado y pequeño** (dozens, no millions). `trace_id`, `request_id`, `email` → NUNCA labels. Si lo necesitás, va en **traces** (Tempo) o **logs** (Loki).

### 11.3 Alerting routing

Alertmanager rutea por labels (`severity`, `team`, `cluster`) a receivers (PagerDuty, Opsgenie, Slack, email, webhook genérico). Patrón:

```yaml
route:
  group_by: ['alertname', 'cluster', 'namespace']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: default-slack
  routes:
    - matchers: [severity="critical"]
      receiver: pagerduty-oncall
    - matchers: [team="payments", severity="warning"]
      receiver: slack-payments
```

---

## 12. Errores comunes y qué evitar

1. **Instalar `kube-prometheus-stack` y declarar victoria.** No. Hay que elegir qué apps instrumentar, escribir ServiceMonitors propios, definir SLOs, escribir runbooks.
2. **Alertas por métricas de infraestructura sueltas** (CPU, memoria). Útiles como *contexto* en dashboards; raramente como alertas accionables.
3. **Logs sin estructura.** Un log `[2024-05-01 12:34:56] something happened` es ruido. Preferí JSON estructurado con `level`, `msg`, `trace_id`, `request_id`.
4. **No definir SLOs.** Sin SLO, no hay "cuánto es demasiado"; cada alerta será una opinión.
5. **Trazas sin propagación de contexto.** Si tu HTTP client no propaga `traceparent` (W3C), tus traces se parten por servicio y pierden valor.
6. **Dashboards sin dueño.** Un dashboard sin dueño es un dashboard muerto; nadie lo arregla cuando una query se vuelve obsoleta.
7. **Scrapear todo**. "Pongamos un `ServiceMonitor` wildcard". Explota cardinalidad y costo. Scrapeá lo que vas a usar.
8. **Alertmanager silenciado**. Silences temporales que se vuelven permanentes = alerta muerta.
9. **No testear reglas.** `promtool test rules` existe. Úsalo en CI para no romper reglas sin querer.
10. **No tener runbook.** Alerta → clic en `runbook_url` → pasos de diagnóstico. Si no está, el on-call improvisa y la gravedad del incidente escala.

---

## Preguntas de evaluación

1. Explicá la diferencia entre `metrics-server` y Prometheus. ¿Puede HPA v2 usar solo `metrics-server`? ¿Para qué sirve `prometheus-adapter`?
2. Un `ServiceMonitor` está creado pero Prometheus no lo scrapea. Listá 5 causas probables.
3. ¿Por qué `rate(cpu) > 0.1 for 1m` es una mala alerta? Reescribila como SLO sobre error-rate HTTP para un servicio web.
4. Diferencia entre Loki (modelo de índice) y Elasticsearch. ¿En qué caso elegirías ES?
5. ¿Qué ventaja te da `exemplars` en Prometheus para correlar métricas con traces?
6. ¿Cuándo elegirías Tempo vs Jaeger?
7. ¿Qué es un `OpenTelemetryCollector` CR y qué pipeline mínimo definirías para traces desde apps → Tempo?
8. Explicá el patrón **multi-window multi-burn-rate** para alertas SLO.
9. ¿Qué labels son peligrosos para la cardinalidad y por qué?
10. Dado un `OOMKilled` recurrente de un Pod, listá: una métrica, un evento, un log y un trace que te ayudarían a diagnosticarlo.
