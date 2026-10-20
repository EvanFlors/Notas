# Recursos — obs-10

## Documentación oficial

- **PromQL — operators (binary matching)** — <https://prometheus.io/docs/prometheus/latest/querying/operators/>
- **PromQL — functions** — <https://prometheus.io/docs/prometheus/latest/querying/functions/>
- **Recording rules** — <https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/>
- **Naming conventions for recording rules** — <https://prometheus.io/docs/practices/rules/>
- **Alerting rules (sintaxis compartida)** — <https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/>
- **TSDB status endpoint** — <https://prometheus.io/docs/prometheus/latest/querying/api/#tsdb-stats>
- **`metric_relabel_configs`** — <https://prometheus.io/docs/prometheus/latest/configuration/configuration/#metric_relabel_configs>
- **Native histograms (features)** — <https://prometheus.io/docs/prometheus/latest/feature_flags/#native-histograms>
- **promtool** — <https://prometheus.io/docs/prometheus/latest/command-line/promtool/>

## Lecturas de referencia

- **"How to detect and troubleshoot high cardinality"** (Grafana Labs blog) — <https://grafana.com/blog/>
- **"Prometheus Query Optimization"** (Prometheus team) — <https://prometheus.io/docs/practices/>
- **kubernetes-mixin recording rules** (ejemplos canónicos, nivel pro) — <https://github.com/kubernetes-monitoring/kubernetes-mixin>
- **SRE Workbook — SLO ingredients** — <https://sre.google/workbook/alerting-on-slos/>
- **Grafana Mimir "cardinality API"** — <https://grafana.com/docs/mimir/latest/manage/mimir-runbooks/>

## Herramientas

- **`promtool test rules`** — <https://prometheus.io/docs/prometheus/latest/configuration/unit_testing_rules/>
- **mimirtool analyze** (identifica métricas no usadas por dashboards/alertas) — <https://grafana.com/docs/mimir/latest/manage/tools/mimirtool/>
- **cortex-tools / cardinality-exporter** — herramientas de terceros para exportar top-N cardinalidad como métricas.

## Comparativa histograms

- **"Native Histograms in Prometheus"** (talk oficial) — <https://prometheus.io/blog/>
- **`prometheus_client` Python — soporte native histograms** — <https://github.com/prometheus/client_python>

## Para el capstone

- RED recording rules de ejemplo del proyecto `kubernetes-mixin`.
- `kube-prometheus-stack` incluye muchas recording rules por default (`values.yaml` → `defaultRules`): referencia operativa real.
- `Sloth` genera burn-rate alerts a partir de recording rules — se usa en `obs-14`.

## Convenciones

- **`:` separator** para recording rule names: `level:metric:operations`.
- Métricas internas Prometheus relevantes: `prometheus_tsdb_head_series`, `prometheus_tsdb_head_chunks`, `prometheus_tsdb_head_series_created_total`, `prometheus_tsdb_head_series_removed_total`, `prometheus_rule_evaluation_duration_seconds`.
