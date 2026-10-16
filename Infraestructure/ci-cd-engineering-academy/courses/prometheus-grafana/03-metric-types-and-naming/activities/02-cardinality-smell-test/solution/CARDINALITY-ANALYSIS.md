# Cardinality analysis — solución de referencia

## Métricas analizadas

- `http_requests_total` (counter) — RED/R y E.
- `http_request_duration_seconds` (histogram) — RED/D.
- `db_query_duration_seconds` (histogram) — latencia DB.
- `cache_hits_total` (counter).
- `queue_depth` (gauge) — profundidad de cola.

## Labels de alta cardinalidad

- `user_id` en `http_requests_total`: unbounded. Cada nuevo usuario = serie nueva. Con 1 M de usuarios: 1 M+ de series por combinación con el resto. Es el caso de libro de cardinality explosion.
- `request_id` en `http_requests_total`: **estrictamente unbounded**, único por request. Multiplica las series por el throughput acumulado. Garantía de colapso de la TSDB.
- `trace_id` en `http_request_duration_seconds`: equivalente a `request_id`. Un trace es único por operación — nunca se usa como label.
- `query` en `db_query_duration_seconds`: incluye el valor literal (`id=12345`). Cada id distinto genera serie nueva. La solución es exponer la consulta **normalizada** (`SELECT * FROM users WHERE id = ?`), no literal.
- `cache_key` en `cache_hits_total`: la clave de caché embebe `user_id` y session ids → unbounded. Lo correcto es dimensión agregable (`cache_name`, no `cache_key`).

## Impacto estimado

Supuestos muy conservadores:
- 100 000 usuarios activos → `user_id` contribuye 100 000 valores.
- 10 requests/s durante 1 día → ~860 000 `request_id` únicos sólo en 24 h (y crece sin tope).
- 1 trace por request → la misma magnitud en `trace_id`.
- Consultas DB con id literal: en el peor caso, un valor por fila consultada.

El producto cartesiano con `method × status × route` (~5 × 10 × 50 = 2 500) multiplicado por `user_id × request_id` lleva fácil a **10⁹+ series** en días. Un Prometheus single-node colapsa con RAM a < 10⁷ series típicamente.

## Propuesta de corrección

- `user_id`, `request_id`, `trace_id`: **dropear** vía `metric_relabel_configs` con `action: labeldrop` sobre los nombres exactos. La correlación por request/trace se hace vía **exemplars** (histograma) o vía logs correlacionados por `trace_id`, no vía label de métrica.
- `query` en DB: cambiar la instrumentación para pasar la query normalizada (`SELECT ... WHERE id = ?`) o quitar la label y conservar `statement_kind` (SELECT/INSERT/UPDATE/DELETE) + `table`.
- `cache_key`: sustituir por `cache_name` (p. ej. `user_profile`, `session`). La granularidad por clave individual pertenece a logs/traces, no a métricas.
- Añadir un panel de "top-10 series por métrica" en Grafana (`topk(10, count by (__name__)({__name__!=""}))`) para detectar regresiones futuras.
- Como red de seguridad, aplicar `metric_relabel_configs` global que droppee cualquier label llamada `*_id` salvo whitelist.
