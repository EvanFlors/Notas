# Recursos — otel-04 Instrumenting Python Traces

## Documentación oficial

- OTel Python docs: https://opentelemetry.io/docs/languages/python/
- Getting started (manual): https://opentelemetry.io/docs/languages/python/getting-started/
- Automatic instrumentation: https://opentelemetry.io/docs/zero-code/python/
- API reference `opentelemetry.trace`: https://opentelemetry-python.readthedocs.io/en/latest/api/trace.html
- SDK reference: https://opentelemetry-python.readthedocs.io/en/latest/sdk/trace.html
- OTLP exporter: https://opentelemetry-python.readthedocs.io/en/latest/exporter/otlp/otlp.html

## Instrumentation packages

- Contrib repo (lista completa): https://github.com/open-telemetry/opentelemetry-python-contrib
- FastAPI: https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/fastapi/fastapi.html
- httpx: https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/httpx/httpx.html
- psycopg: https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/psycopg/psycopg.html
- Redis: https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/redis/redis.html

## Semantic Conventions

- Semconv repo: https://github.com/open-telemetry/semantic-conventions
- HTTP conventions (v1): https://opentelemetry.io/docs/specs/semconv/http/http-spans/
- Database conventions: https://opentelemetry.io/docs/specs/semconv/database/database-spans/
- Messaging conventions: https://opentelemetry.io/docs/specs/semconv/messaging/messaging-spans/
- General span attributes: https://opentelemetry.io/docs/specs/semconv/general/attributes/

## Specification

- Spec (API + SDK + data model): https://github.com/open-telemetry/opentelemetry-specification
- Status by signal/language: https://opentelemetry.io/status/
- Span kinds: https://opentelemetry.io/docs/specs/otel/trace/api/#spankind
- Status codes: https://opentelemetry.io/docs/specs/otel/trace/api/#set-status

## Collector / Backend

- OTel Collector docs: https://opentelemetry.io/docs/collector/
- OTLP protocol: https://opentelemetry.io/docs/specs/otlp/
- Grafana Tempo: https://grafana.com/docs/tempo/latest/

## Lecturas y buenas prácticas

- "Instrumenting your code" (OTel blog): https://opentelemetry.io/blog/
- "Span attributes vs events" (CNCF discussion): https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/api.md#add-events
- "Why head and tail sampling both matter" (Honeycomb): https://www.honeycomb.io/blog/sampling-your-traces
- "Zero-code eBPF vs OTel SDK" (Odigos): https://odigos.io/
