# Recursos — otel-11 Backends y multi-exportación

## Tempo

- Tempo docs: https://grafana.com/docs/tempo/latest/
- TraceQL reference: https://grafana.com/docs/tempo/latest/traceql/
- Tempo architecture: https://grafana.com/docs/tempo/latest/operations/architecture/
- Tempo + OTel Collector: https://grafana.com/docs/tempo/latest/configuration/otel-collector/

## Jaeger

- Jaeger docs: https://www.jaegertracing.io/docs/
- OTLP support in Jaeger: https://www.jaegertracing.io/docs/latest/deployment/#opentelemetry
- Jaeger storage backends (Cassandra, Elasticsearch): https://www.jaegertracing.io/docs/latest/deployment/#storage-backends
- Deprecation of jaeger-client SDKs in favor of OTel SDKs: https://www.jaegertracing.io/docs/latest/client-libraries/

## Loki (recap)

- Loki OTLP ingest: https://grafana.com/docs/loki/latest/send-data/otel/
- `loki` exporter (deprecated) migration note: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/lokiexporter

## Prometheus & OTel

- Prometheus OTLP ingest flag: https://prometheus.io/docs/prometheus/latest/feature_flags/#otlp-receiver
- `prometheusexporter` (expose /metrics): https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/prometheusexporter
- `prometheusremotewriteexporter`: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/prometheusremotewriteexporter
- OTel ↔ Prometheus compatibility doc: https://opentelemetry.io/docs/specs/otel/compatibility/prometheus_and_openmetrics/

## Vendor backends (OTLP-compatible)

- Datadog exporter: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/datadogexporter
- Datadog OTLP ingest reference: https://docs.datadoghq.com/opentelemetry/
- Honeycomb OTLP: https://docs.honeycomb.io/get-started/start-building/application/opentelemetry/
- New Relic OTLP: https://docs.newrelic.com/docs/opentelemetry/best-practices/opentelemetry-otlp/
- Grafana Cloud OTLP: https://grafana.com/docs/grafana-cloud/send-data/otlp/
- Lightstep (ServiceNow Cloud Observability) OTLP: https://docs.lightstep.com/otel/opentelemetry

## Multi-export patterns

- OTel Collector pipelines (fan-out semantics): https://opentelemetry.io/docs/collector/configuration/#service
- Grafana blog "Migrating from Jaeger to Tempo": https://grafana.com/blog/
- "Running two backends in parallel" (community pattern, search upstream issues).

## Collector self-telemetry

- Internal observability: https://opentelemetry.io/docs/collector/internal-telemetry/
- Key metrics (otelcol_exporter_*, otelcol_processor_dropped_*): same page.
- Health check extension: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/healthcheckextension

## Lecturas de equipo

- "Observability Engineering" (Majors, Fong-Jones, Miranda) — capítulos sobre portabilidad vendor y pilares.
- ADR templates (Michael Nygard original): https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
- Google SRE Workbook — capítulos sobre monitoring y data stores de telemetría.

## Herramientas asociadas

- `telemetrygen` (dentro de opentelemetry-collector-contrib) para generar traces/metrics/logs sintéticos.
- Grafana Alloy como alternativa de agente (sucesor de Promtail/Grafana Agent).
- OpenTelemetry Operator (otel-12) para desplegar Collector + Instrumentation en K8s.
