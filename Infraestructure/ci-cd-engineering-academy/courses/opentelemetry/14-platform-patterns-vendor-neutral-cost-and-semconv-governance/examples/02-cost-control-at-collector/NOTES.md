# Notas de operación — cost control

## Cómo ajustar las quotas por servicio

- Cada servicio con tráfico > 100 RPS recibe su propia policy `and` (by-service + probabilistic).
- Default sample rate (2%) actúa como "catch-all" para servicios no listados.
- Revisar quotas trimestralmente contra la factura.

## Cómo medir el ahorro

El Collector expone en `:8888/metrics`:

- `otelcol_processor_tail_sampling_sampling_trace_dropped_too_early`
- `otelcol_processor_tail_sampling_count_traces_sampled`
- `otelcol_processor_batch_batch_send_size`
- `otelcol_exporter_sent_spans` / `_metric_points` / `_log_records`

Comparando `receiver_accepted_spans` vs `exporter_sent_spans` tienes la tasa de drop total. Objetivo deseado típico: 70-85% de traces droppeados (manteniendo el 100% de errores) en servicios high-volume.

## Peligros

- `cumulativetodelta` **cambia la semántica** de la métrica. Si el backend asume cumulative (Prometheus clásico), romperás histogramas. Usar sólo cuando el exporter aguas abajo entiende delta (Datadog, OTLP ingest nativo con delta).
- `interval` 60s pierde picos sub-minuto. No usar en pipelines críticos de latencia (SLO de 1s, por ejemplo).
- Borrar `k8s.pod.name` quita la posibilidad de diagnosticar "este pod en concreto". Mantén el label en logs (donde la cardinalidad se gestiona distinto) aunque lo dropees en métricas.
