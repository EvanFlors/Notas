# Ejemplo 02 — Middleware RED

Middleware ASGI que mide **R**ate (Counter), **E**rrors (status_class) y **D**uration (Histogram) para cualquier endpoint FastAPI, con cardinalidad controlada.

## Claves de diseño

- `path` templatizado: `/items/{item_id}` en vez de `/items/42`.
- `status_class` (`2xx`, `4xx`, `5xx`) en lugar del código: 5 valores vs ~40.
- Rutas no reconocidas se agrupan en `path="unmatched"` (evita que un escáner infle cardinalidad).
- `INFLIGHT` como `Gauge` por `method` para capacidad / saturation.

## Correr

```bash
cd $(dirname "$0")
bash run.sh
```

## Lo que verás en /metrics

```
http_requests_total{method="GET",path="/items/{item_id}",status_class="2xx"} 1
http_requests_total{method="GET",path="/items/{item_id}",status_class="4xx"} 1
http_requests_total{method="GET",path="/health",status_class="2xx"} 1
http_request_duration_seconds_bucket{method="GET",path="/items/{item_id}",le="0.025"} 2
http_requests_inflight{method="GET"} 0
```

## PromQL de RED a partir de estas métricas

```promql
# Rate (requests/segundo) por path
sum by (path) (rate(http_requests_total[1m]))

# Errores (5xx) por path
sum by (path) (rate(http_requests_total{status_class="5xx"}[1m]))

# P99 latencia por path
histogram_quantile(
  0.99,
  sum by (le, path) (rate(http_request_duration_seconds_bucket[5m]))
)
```
