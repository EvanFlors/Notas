# Ejemplo 02 — RED vs USE

Tabla ejemplar del contrato de observabilidad de dos sujetos distintos: un servicio HTTP (RED) y un disco (USE). Útil como plantilla al diseñar la instrumentación de un nuevo servicio.

## RED para un servicio HTTP (`checkout-api`)

| Letra | Métrica | Tipo | Unidad | Labels OK | Labels PROHIBIDAS |
|---|---|---|---|---|---|
| R — Rate | `http_requests_total` | counter | — | `method`, `route`, `status` | `user_id`, `request_id`, `path` con IDs |
| E — Errors | `http_requests_total{status=~"5.."}` | (derivado del counter R) | — | `status` | — |
| D — Duration | `http_request_duration_seconds` | histogram | seconds | `method`, `route` | `user_id`, `request_id` |

Queries típicas (se escribirán en `obs-04`):

```promql
# Rate global
sum(rate(http_requests_total{job="checkout-api"}[5m]))

# Error ratio (SLI de disponibilidad)
sum(rate(http_requests_total{job="checkout-api",status=~"5.."}[5m]))
/
sum(rate(http_requests_total{job="checkout-api"}[5m]))

# p95 de latencia agregado cross-replica
histogram_quantile(
  0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket{job="checkout-api"}[5m]))
)
```

## USE para un disco (`/dev/nvme0n1`)

| Letra | Métrica | Tipo | Unidad |
|---|---|---|---|
| U — Utilization | `node_disk_io_time_seconds_total` | counter | seconds |
| S — Saturation | `node_disk_io_time_weighted_seconds_total` | counter | seconds |
| E — Errors | (vía `smartctl_device_error_count`) | counter | — |

```promql
# % de tiempo que el disco estuvo ocupado
rate(node_disk_io_time_seconds_total{device="nvme0n1"}[5m])

# Queue latency aggregate (saturation)
rate(node_disk_io_time_weighted_seconds_total{device="nvme0n1"}[5m])
```

## Observaciones

- RED se calcula desde la **app** (instrumentación propia).
- USE se calcula desde **exporters** (`node_exporter`, `cAdvisor`, `smartctl_exporter`).
- Un servicio bien observado tiene **ambos**: RED arriba y USE abajo, para separar "hay dolor para el usuario" de "qué recurso está apretado".
