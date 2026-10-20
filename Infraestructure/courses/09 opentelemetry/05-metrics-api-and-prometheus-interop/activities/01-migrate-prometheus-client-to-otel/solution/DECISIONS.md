# Decisiones de la migración

## Temporalidad: CUMULATIVE

Prometheus asume que un contador reporta su valor **acumulado monotónico** desde
el arranque del proceso. La función `rate(...)` deriva internamente el delta
entre scrapes. Por eso el `MeterProvider` conserva el default
`AggregationTemporality.CUMULATIVE`.

Si cambiáramos a `DELTA`:

- Los contadores exportarían solo el incremento entre exports.
- Prometheus los interpretaría como "resets" continuos.
- `rate()` quedaría plano o errático; las alertas sobre throughput dejarían de disparar.

Si en el futuro un backend StatsD-like exigiese `DELTA`, la conversión se haría
en el **Collector** con el processor `cumulativetodelta`, no cambiando la app.

## Qué migraría a continuación

- Métricas de negocio custom (`orders_created_total`, `payment_errors_total`).
- Latencia por operación de dominio (`checkout.duration`).

## Qué dejaría en `prometheus_client` (o fuera de OTel) por ahora

- Métricas de infraestructura expuestas por terceros (`node_exporter`, `kube-state-metrics`).
- Librerías internas sin apetito de reinstrumentación hasta su siguiente major.

## Doble emisión: evitada

Las métricas `http_requests_total` y `http_request_duration_seconds` del
`prometheus_client` fueron reemplazadas en el mismo commit por sus equivalentes
OTel; no quedan registradas dos veces en el registry.
