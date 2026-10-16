# Recursos — otel-06-logs-api-and-bridges

## Especificación

- [OTel Logs Data Model](https://opentelemetry.io/docs/specs/otel/logs/data-model/) — definición de campos del `LogRecord`.
- [OTel Logs Overview](https://opentelemetry.io/docs/concepts/signals/logs/) — por qué logs es el signal más joven y cómo se piensa.
- [OTel Logs Bridge API Spec](https://opentelemetry.io/docs/specs/otel/logs/bridge-api/) — superficie que los framework bridges deben implementar.

## Python SDK

- [opentelemetry-python — Logs](https://opentelemetry-python.readthedocs.io/en/latest/sdk/logs.html) — docs del SDK.
- [`opentelemetry-sdk._logs.LoggingHandler`](https://opentelemetry-python.readthedocs.io/en/latest/sdk/_logs.html#opentelemetry.sdk._logs.LoggingHandler) — el bridge para `logging` del stdlib.
- [opentelemetry-exporter-otlp-proto-grpc](https://pypi.org/project/opentelemetry-exporter-otlp-proto-grpc/) — exporter OTLP gRPC con soporte para logs.
- [opentelemetry-instrumentation-logging](https://pypi.org/project/opentelemetry-instrumentation-logging/) — inyecta `trace_id`/`span_id` como campos del formatter del `logging` stdlib (complementario, **no** reemplaza al bridge).

## Collector

- [OTel Collector — logs pipeline](https://opentelemetry.io/docs/collector/configuration/#logs-pipeline).
- [`loki` exporter (contrib)](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/lokiexporter) — convierte LogRecords a formato Loki push.
- [`filelog` receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver) — alternativa a emitir OTLP: lee archivos de logs y los sube.

## Grafana / Loki

- [Grafana `tracesToLogsV2` config](https://grafana.com/docs/grafana/latest/datasources/tempo/#trace-to-logs) — campo clave para el click-through.
- [Loki — LogQL `| json`](https://grafana.com/docs/loki/latest/query/log_queries/#json) — para query por attribute del log OTLP.
- [Loki — labels vs structured metadata](https://grafana.com/docs/loki/latest/get-started/labels/) — por qué no promover todo a label.

## Correlación cross-signal

- [OTel Exemplars](https://opentelemetry.io/docs/specs/otel/metrics/data-model/#exemplars) — complementa logs: una métrica puede apuntar al trace de ejemplo.
- [Grafana Explore — Split View](https://grafana.com/docs/grafana/latest/explore/explore-dashboards/) — flujo de trace→log en la misma vista.

## Madurez y status

- [OTel language status page](https://opentelemetry.io/docs/languages/) — ver Python/Logs = GA.
- [opentelemetry-python CHANGELOG](https://github.com/open-telemetry/opentelemetry-python/blob/main/CHANGELOG.md) — ritmo de breaking changes en `_logs`.

## Lectura crítica

- Grafana — ["Correlating traces, logs, and metrics with OTel"](https://grafana.com/blog/2023/06/05/opentelemetry-at-grafana-labs-the-learning-materials-and-tutorials-you-need/) (buscar artículo vigente).
- Honeycomb — "Logs vs events in OTel": por qué un `logRecord` OTel bien hecho se acerca al concepto de "event" y no al de "line".
