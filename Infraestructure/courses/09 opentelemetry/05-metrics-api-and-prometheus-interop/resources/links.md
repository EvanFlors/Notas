# Recursos — otel-05 Metrics API y Prometheus interop

## Documentación oficial

- OpenTelemetry Python — Metrics API: <https://opentelemetry.io/docs/languages/python/instrumentation/#metrics>
- Metrics data model (spec): <https://opentelemetry.io/docs/specs/otel/metrics/data-model/>
- Metrics SDK (spec): <https://opentelemetry.io/docs/specs/otel/metrics/sdk/>
- Supplementary guidelines (naming, units): <https://opentelemetry.io/docs/specs/otel/metrics/supplementary-guidelines/>
- Semantic conventions — HTTP metrics: <https://opentelemetry.io/docs/specs/semconv/http/http-metrics/>

## Interop con Prometheus

- OTel ↔ Prometheus interop (spec): <https://opentelemetry.io/docs/specs/otel/compatibility/prometheus_and_openmetrics/>
- `opentelemetry-exporter-prometheus` (Python): <https://pypi.org/project/opentelemetry-exporter-prometheus/>
- Prometheus OTLP ingest (`/api/v1/otlp/v1/metrics`): <https://prometheus.io/docs/prometheus/latest/feature_flags/#otlp-receiver>
- Collector `prometheusremotewrite` exporter: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/prometheusremotewriteexporter>
- Collector `prometheusreceiver`: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/prometheusreceiver>

## Exemplars

- Prometheus exemplars docs: <https://prometheus.io/docs/prometheus/latest/feature_flags/#exemplars-storage>
- Grafana — exemplars datasource config: <https://grafana.com/docs/grafana/latest/datasources/prometheus/configure-prometheus-data-source/#exemplars>
- OTel spec — exemplar: <https://opentelemetry.io/docs/specs/otel/metrics/data-model/#exemplars>

## Temporality

- Collector `cumulativetodelta` processor: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/cumulativetodeltaprocessor>
- Collector `deltatocumulative` processor: <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/deltatocumulativeprocessor>

## Comparación / background

- `prometheus_client` Python: <https://github.com/prometheus/client_python>
- Blog oficial sobre OTel + Prometheus (CNCF): <https://opentelemetry.io/blog/2024/prom-and-otel/>
- Status de métricas por lenguaje: <https://opentelemetry.io/status/>

## Lecturas recomendadas

- "Why Cumulative Temporality for Prometheus" — issues del repo opentelemetry-specification.
- Chapter 4 de "Learning OpenTelemetry" (O'Reilly, Young & Parker, 2024) — Metrics API en profundidad.
