# Recursos — context propagation

## Especificación
- W3C Trace Context: https://www.w3.org/TR/trace-context/
- W3C Baggage: https://www.w3.org/TR/baggage/
- OpenTelemetry context specification: https://opentelemetry.io/docs/specs/otel/context/
- OpenTelemetry context API (Python): https://opentelemetry-python.readthedocs.io/en/latest/api/context.html

## Propagators
- `opentelemetry.propagate` (Python): https://opentelemetry-python.readthedocs.io/en/latest/api/propagate.html
- B3 propagator: https://github.com/open-telemetry/opentelemetry-python-contrib/tree/main/propagator/opentelemetry-propagator-b3
- Jaeger propagator: https://github.com/open-telemetry/opentelemetry-python-contrib/tree/main/propagator/opentelemetry-propagator-jaeger

## Instrumentations relevantes
- FastAPI: https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/fastapi/fastapi.html
- httpx / requests: https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/httpx/httpx.html
- gRPC: https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/grpc/grpc.html
- Kafka (kafka-python / confluent-kafka): https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/kafka_python/kafka_python.html
- AWS botocore (SQS/SNS message attributes): https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/botocore/botocore.html

## Async y ContextVars
- PEP 567 — ContextVars: https://peps.python.org/pep-0567/
- Python `contextvars` module: https://docs.python.org/3/library/contextvars.html

## Patrones y guías
- OTel docs — propagating context: https://opentelemetry.io/docs/languages/python/propagation/
- Messaging semconv: https://opentelemetry.io/docs/specs/semconv/messaging/
- Debugging missing spans (Honeycomb): https://docs.honeycomb.io/get-started/debugging-missing-spans/
