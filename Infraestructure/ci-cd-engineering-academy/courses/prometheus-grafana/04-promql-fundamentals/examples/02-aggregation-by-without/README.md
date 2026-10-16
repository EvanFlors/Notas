# Ejemplo 02 — Agregación: `by` vs `without`

Mismo input, 4 agregaciones distintas. El objetivo es desarrollar intuición de qué labels se **conservan** y cuáles **colapsan**.

## Dato de entrada (conceptual)

```
http_requests_total{job="api", instance="a:9100", method="GET",  code="200"} 100
http_requests_total{job="api", instance="a:9100", method="POST", code="200"} 50
http_requests_total{job="api", instance="b:9100", method="GET",  code="500"} 10
http_requests_total{job="api", instance="b:9100", method="POST", code="200"} 20
http_requests_total{job="web", instance="c:9100", method="GET",  code="200"} 300
```

## Queries y resultado esperado

| Query | Series resultantes |
|-------|---------------------|
| `sum(rate(http_requests_total[5m]))` | **1 serie** (todo colapsa) |
| `sum by (job) (rate(http_requests_total[5m]))` | **2 series** (job=api, job=web) |
| `sum by (job, method) (rate(http_requests_total[5m]))` | **3 series** |
| `sum without (instance) (rate(http_requests_total[5m]))` | 1 por combinación {job, method, code} |
| `topk(2, sum by (job, method) (rate(http_requests_total[5m])))` | **2 series top** |

Ver [`queries.promql`](queries.promql).

## Ejecución

```bash
bash run.sh
```

Reutiliza el mismo patrón de `01-rate-increase-irate/run.sh`: usa Prometheus si está, si no `promtool`, si no SKIP.
