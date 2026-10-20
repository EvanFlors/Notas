# Curso: Prometheus + Grafana (observabilidad)

Roadmap especializado #10. Observabilidad centrada en **métricas** con Prometheus y visualización/alerting con Grafana. Se incluye **Loki** (logs) como extensión natural del stack Grafana y **Alertmanager** como componente de primera clase. **Traces** y la capa de instrumentación con **OpenTelemetry** se tratan en el curso #11 aparte, aunque se integran al final.

## 1. Introducción

### Qué es

**Prometheus** es un sistema de monitoreo y alerting basado en:

- **Modelo pull**: Prometheus *scrapea* endpoints HTTP (`/metrics`) de los targets.
- **Modelo de datos de series de tiempo**: cada muestra es `(metric_name{label=value, ...}, timestamp, value)`.
- **Base de datos TSDB local** (en disco), optimizada para write-heavy y queries temporales.
- **Lenguaje de consulta propio: PromQL**.
- **Service discovery** nativo (K8s, Consul, EC2, file-based, etc.) para encontrar qué scrapear.
- **Alertmanager** como componente separado que recibe alertas disparadas por reglas Prometheus y las enruta/agrupa/silencia.

**Grafana** es la UI de visualización líder para datos de observabilidad. No es exclusiva de Prometheus: conecta a decenas de data sources (Prometheus, Loki, Tempo, Elasticsearch, CloudWatch, BigQuery, Postgres, etc.). Lo que se visualiza en Grafana vive en el data source.

El stack típico "LGTM" promovido por Grafana Labs:
- **L**oki — logs.
- **G**rafana — UI.
- **T**empo — traces.
- **M**imir / **Prometheus** — métricas.

Este curso cubre **Prometheus + Grafana + Alertmanager + Loki**. Tempo/traces y OTel se cubren en el curso de OpenTelemetry.

### Historia (síntesis)

- **2012** — SoundCloud desarrolla Prometheus inspirado en Borgmon de Google.
- **2015** — Open source público.
- **2016** — Grafana Labs se consolida como empresa (Grafana existe desde 2014).
- **2016** — Prometheus se incorpora a la CNCF como segundo proyecto graduado tras Kubernetes.
- **2018** — Prometheus Operator estabiliza; **kube-prometheus-stack** se convierte en el camino default para K8s.
- **2019+** — Soluciones long-term storage: **Thanos**, **Cortex**, luego **Grafana Mimir** y **VictoriaMetrics**.
- **2021** — **Loki** 2.0 (índice separable del storage) y **Tempo** 1.0.
- **2024+** — Mejoras de PromQL, **native histograms** (sparse, mucho más eficientes que las histogram buckets tradicionales), Grafana 11, mejor integración OTel.

### Problemas que resuelve

- **Detectar fallos y degradaciones** en tiempo real.
- **Diagnosticar** cuándo, dónde y por qué pasó algo (correlacionando métricas con logs y traces).
- **Alertar** a humanos solo cuando hace falta (y no cuando no).
- **Medir SLIs y gestionar SLOs** con rigor, en lugar de "sentir" si el sistema va bien.
- **Capacity planning** basado en tendencias históricas.

### Casos de uso

- Monitoreo de infraestructura (nodos, discos, red, procesos).
- Monitoreo de aplicaciones (requests, errores, latencias, saturación).
- Monitoreo de Kubernetes (control plane, nodos, workloads, add-ons).
- Monitoreo de servicios managed (RDS, EKS, S3) vía exporters o CloudWatch Exporter.
- Alerting SLO-based y burn-rate.

### Arquitectura general

```
┌───────────────────────────────────────────────┐
│ Targets (apps, exporters, cAdvisor, …)        │
│   expone /metrics (text format)               │
└───────────────────────────────────────────────┘
             ▲ pull cada N segundos
             │
┌───────────────────────────────────────────────┐
│ Prometheus                                    │
│  - service discovery (SD)                     │
│  - relabel                                    │
│  - scrape + ingest a TSDB local               │
│  - evalúa recording rules & alerting rules    │
│  - envía alerts activas a Alertmanager        │
└───────────────────────────────────────────────┘
      │                       │
      │ PromQL                │ POST alerts
      ▼                       ▼
┌─────────────┐       ┌───────────────────────┐
│ Grafana     │       │ Alertmanager          │
│  - dashboards       │   - deduplicate       │
│  - alerting UI      │   - group / inhibit   │
│  - también lee Loki │   - silences          │
│    y Tempo          │   - route → receivers │
└─────────────┘       └───────────────────────┘
                              │
                              ▼
                     Slack / Email / PagerDuty / webhook
```

Para **escala horizontal y retención larga** se agregan al stack: **Thanos** (sidecar + store + querier) o **Grafana Mimir** o **VictoriaMetrics**. Para K8s se usa **Prometheus Operator** (CRDs `ServiceMonitor`, `PodMonitor`, `PrometheusRule`, `Alertmanager`, `Probe`, `ScrapeConfig`).

### Alternativas

- **Datadog, New Relic, Dynatrace, Honeycomb, Chronosphere, Grafana Cloud** — SaaS comerciales.
- **InfluxDB + Telegraf** — pull alternativo (push model).
- **OpenSearch/Elasticsearch + Kibana** — fuerte en logs, menos en métricas.
- **VictoriaMetrics** — drop-in para Prometheus con mejor rendimiento a escala.
- **AWS CloudWatch / Cloud Monitoring de GCP** — nativos cloud (menos portables).

### Ventajas / limitaciones

**Ventajas**: estándar de facto, enorme ecosistema de exporters, modelo pull simple y auditable, PromQL expresivo, Grafana es la UI que todo el mundo conoce, stack 100% open source.

**Limitaciones / riesgos**:
- **Cardinality explosion**: una label con alta cardinalidad (user_id, request_id) hace crecer la TSDB a O(cardinalidad total) — fuente #1 de incidentes operativos.
- Prometheus single-node tiene límites prácticos (RAM, retención); escala horizontal requiere Thanos/Mimir/VictoriaMetrics.
- **Logs** no son el fuerte de Prometheus (de ahí Loki).
- Alert fatigue si no se diseña con disciplina SLO.
- Grafana dashboards se multiplican descontroladamente; sin gobernanza se vuelven ruido.

### Relación con el programa

- Base de **D10 Observabilidad y SRE** del programa.
- Target natural de los **ServiceMonitors** del capstone (Prometheus Operator en K8s).
- Puente con **Argo Rollouts**: AnalysisTemplate consume PromQL para decidir promover canary.
- Fundamento operativo de **SLI/SLO** y burn-rate alerts.
- Panorama complementario al curso **OpenTelemetry** (métricas pueden fluir OTel → Prometheus; logs OTel → Loki; traces OTel → Tempo).

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | Nociones básicas de HTTP y de sistemas (CPU/memoria/latencia). Curso **docker** completo (todo corre en contenedores). |
| Recomendados | Curso **kubernetes** ≥ Nivel 2 (Prometheus Operator vive en K8s). Un lenguaje para instrumentar (Python aquí). |
| Complementarios | Curso **argocd-gitops** si se gestionan dashboards/alertas por GitOps. |

## 3. Organización (4 niveles)

El curso tiene **15 módulos**. Detalle en `ROADMAP.md`.

- **Nivel 1 — Fundamentos** (4): principios de observabilidad y modelo pull, instalación local y UI, tipos de métricas y naming, PromQL básico.
- **Nivel 2 — Intermedio** (5): exporters y relabeling, service discovery, instrumentación de app Python, Grafana en profundidad, Alertmanager.
- **Nivel 3 — Avanzado** (4): PromQL avanzado + recording rules + control de cardinalidad, escala y long-term storage (Thanos/Mimir/VictoriaMetrics), Prometheus Operator + kube-prometheus-stack, Loki para logs.
- **Nivel 4 — Producción empresarial** (2): SLI/SLO/error budgets + burn-rate alerts, platform patterns (dashboards y alertas como código, gobernanza, costo de observabilidad).

## 4. Entregables del curso

- Stack local (docker-compose) con Prometheus + Grafana + Alertmanager + Loki + app Python instrumentada.
- Mismo stack portado a K8s via **kube-prometheus-stack** con `ServiceMonitor` para el capstone.
- Dashboards del capstone en Grafana versionados como JSON y provisionados.
- Alertas Prometheus versionadas como YAML (`PrometheusRule`) con tests (`promtool`).
- SLO formal con burn-rate alerts (multi-window multi-burn-rate).
- ADR sobre long-term storage (Thanos vs Mimir vs VictoriaMetrics) para una org dada.

## 5. Evaluación

- **Conceptual**: diferenciar counter/gauge/histogram/summary; qué garantiza y qué no un `increase()` sobre un counter; cardinality y su impacto; por qué pull > push para este caso.
- **Operativa**: instrumentar un endpoint y verlo en Grafana; escribir una PromQL que calcule error rate SLI; configurar Alertmanager con routes y silences; levantar kube-prometheus-stack.
- **Arquitectónica**: diseñar la retención y la estrategia de escala; definir SLOs; política de dashboards; evaluar costos (storage, cardinality, LB egress).

## 6. Recursos

A verificar en Fase 4:

- Documentación oficial Prometheus (`prometheus.io/docs/`), Alertmanager, Grafana, Loki.
- *The RED Method* (Tom Wilkie) y *USE Method* (Brendan Gregg).
- *SRE Workbook* y *SRE Book* de Google (capítulos de SLI/SLO/burn-rate).
- Prometheus Operator y kube-prometheus-stack chart.
- `kubernetes-mixin` (dashboards + alerts oficiales para K8s).
- Documentación de Thanos, Mimir, VictoriaMetrics.
- `promtool` (parte de la distribución Prometheus) para test de reglas.
