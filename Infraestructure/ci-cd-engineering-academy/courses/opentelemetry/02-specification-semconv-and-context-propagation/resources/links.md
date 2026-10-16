# Recursos — otel-02

## Especificación

- OpenTelemetry Specification (repo): https://github.com/open-telemetry/opentelemetry-specification
- OTLP (OpenTelemetry Protocol): https://opentelemetry.io/docs/specs/otlp/
- Data model (traces/metrics/logs): https://opentelemetry.io/docs/specs/otel/

## Semantic Conventions

- Semantic Conventions (repo): https://github.com/open-telemetry/semantic-conventions
- HTTP semconv: https://opentelemetry.io/docs/specs/semconv/http/
- Resource semconv (service.*, k8s.*, host.*): https://opentelemetry.io/docs/specs/semconv/resource/
- Database semconv: https://opentelemetry.io/docs/specs/semconv/database/
- Messaging semconv: https://opentelemetry.io/docs/specs/semconv/messaging/
- Migration guide HTTP (`http.method` → `http.request.method`): https://opentelemetry.io/docs/specs/semconv/non-normative/http-migration/

## Context Propagation

- W3C Trace Context (recomendación): https://www.w3.org/TR/trace-context/
- W3C Baggage: https://www.w3.org/TR/baggage/
- OTel propagators overview: https://opentelemetry.io/docs/concepts/context-propagation/
- Variable `OTEL_PROPAGATORS`: https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/

## Lecturas recomendadas

- "Why W3C Trace Context matters" (OTel blog): https://opentelemetry.io/blog/
- Honeycomb — Guide to naming conventions: https://docs.honeycomb.io/
- Grafana — Working with traces in Tempo: https://grafana.com/docs/tempo/latest/
