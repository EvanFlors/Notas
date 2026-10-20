# Ejemplo 03 — `histogram_quantile`

Calcular p50/p95/p99 de forma correcta a partir de un histogram clásico.

## Dato de entrada (conceptual)

```
http_request_duration_seconds_bucket{le="0.1",  job="api"} 500
http_request_duration_seconds_bucket{le="0.25", job="api"} 800
http_request_duration_seconds_bucket{le="0.5",  job="api"} 950
http_request_duration_seconds_bucket{le="1.0",  job="api"} 990
http_request_duration_seconds_bucket{le="+Inf", job="api"} 1000
http_request_duration_seconds_sum{job="api"}   180.0
http_request_duration_seconds_count{job="api"} 1000
```

## Reglas de oro

1. `rate(..._bucket[5m])` **antes** de agregar (es un counter).
2. `sum by (le, ...)`: `le` **nunca** sale del `by`.
3. Agregar las dimensiones adicionales que se quieran preservar (`job`, `path`, `method`).

## Queries

Ver [`queries.promql`](queries.promql).

## Lectura esperada (sobre el input de arriba)

| Query | Valor esperado |
|-------|-----------------|
| `histogram_quantile(0.50, …)` | ~0.13s (entre bucket 0.1 y 0.25) |
| `histogram_quantile(0.95, …)` | ~0.5s |
| `histogram_quantile(0.99, …)` | ~1.0s |
| media = `rate(_sum)/rate(_count)` | ~0.18s |

## Anti-patrón

Ver `queries.promql` líneas con `# MAL`: olvidar `le` en el `by` da cuantiles sin sentido o `NaN`.

## Ejecución

```bash
bash run.sh
```
