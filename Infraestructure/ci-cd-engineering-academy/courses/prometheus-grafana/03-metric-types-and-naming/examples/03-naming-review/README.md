# Ejemplo 03 — naming review (antes / después)

Catálogo de errores de naming típicos y su reescritura canónica.

| Mal | Bien | Razón |
|---|---|---|
| `httpRequests` | `http_requests_total` | camelCase y falta sufijo counter |
| `requests` | `http_requests_total` | nombre genérico sin namespace |
| `request_count` | `http_requests_total` | `_total` es la convención counter |
| `latency_ms` | `http_request_duration_seconds` | unidad canónica es `seconds` |
| `response_time_milliseconds` | `http_request_duration_seconds` | ídem |
| `cpu_usage_percent` | `cpu_usage_ratio` | ratio 0..1, no 0..100 |
| `disk_usage_percent` | `disk_usage_ratio` | ídem |
| `memory_used_mb` | `process_memory_used_bytes` | `_bytes` siempre, nunca `_mb/_kb/_gb` |
| `queue_size_total` | `queue_size` | `size` es gauge, no monótono |
| `active_connections_total` | `active_connections` | "active" es un gauge (sube y baja) |
| `uptime` | `process_start_time_seconds` | el idiom Prometheus para uptime es "cuándo arrancó" |
| `errors` | `http_errors_total` | counter con namespace + `_total` |
| `kafka_LagPerPartition` | `kafka_consumer_lag` | snake_case; "lag" es gauge |
| `api_v1_users_get_requests` | `http_requests_total` (con label `route="/api/v1/users"`) | no metas el path en el nombre |
| `requests_200`, `requests_404`, `requests_500` | `http_requests_total` (con label `status="200"`, etc.) | el status es dimensión, no métrica |

## Olores (smells) adicionales

- Nombre con mayúsculas (`http_request_Duration`).
- Nombre en plural donde no corresponde (`http_requests_durations_seconds`).
- Dos unidades (`http_request_duration_seconds_ms`).
- `_total` en algo que no es monótono.
- `_bytes` que en realidad son megabytes.
- `_ratio` que va de 0 a 100.
- Métrica distinta por cada combinación de dimensiones en vez de usar labels.
