# Recursos — otel-14

## Especificación y convenciones

- OpenTelemetry Semantic Conventions (upstream): https://github.com/open-telemetry/semantic-conventions
- Semantic Conventions release notes & migration guides: https://opentelemetry.io/docs/specs/semconv/
- HTTP semconv migration (`http.method` → `http.request.method`): https://opentelemetry.io/docs/specs/semconv/http/migration-guide/

## Collector

- OpenTelemetry Collector (core + contrib): https://github.com/open-telemetry/opentelemetry-collector-contrib
- Tail sampling processor: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/tailsamplingprocessor
- Transform processor + OTTL: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor
- k8sattributes processor: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/k8sattributesprocessor
- Interval processor: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/intervalprocessor
- Cumulative-to-delta processor: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/cumulativetodeltaprocessor
- Datadog exporter: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/datadogexporter

## Operator y K8s

- OpenTelemetry Operator: https://github.com/open-telemetry/opentelemetry-operator
- Instrumentation CR (auto-inject): https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/api.md#instrumentation

## Backends y vendor docs

- Grafana Tempo: https://grafana.com/docs/tempo/latest/
- Grafana Loki OTLP ingest: https://grafana.com/docs/loki/latest/send-data/otel/
- Prometheus OTLP ingest: https://prometheus.io/docs/prometheus/latest/feature_flags/#otlp-receiver
- Datadog OTLP ingest: https://docs.datadoghq.com/opentelemetry/
- Grafana Alloy (sucesor de Agent): https://grafana.com/docs/alloy/latest/
- AWS Distro for OpenTelemetry (ADOT): https://aws-otel.github.io/

## Patrones de plataforma

- Backstage (IDP): https://backstage.io/
- Backstage software templates: https://backstage.io/docs/features/software-templates/
- Platform engineering playbook (CNCF): https://tag-app-delivery.cncf.io/whitepapers/platforms/

## ADRs y governance

- MADR (Markdown ADR) template: https://adr.github.io/madr/
- "Documenting Architecture Decisions" (Michael Nygard): https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions

## Material complementario

- OpenTelemetry Status Page (madurez por lenguaje/signal): https://opentelemetry.io/status/
- OpenTelemetry Enhancement Proposals (OTEPs): https://github.com/open-telemetry/oteps
