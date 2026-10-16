# Fixture — métricas realmente expuestas por el servicio

`scrape_interval: 15s` en `prometheus.yml`.

```
# TYPE http_requests_total counter
http_requests_total{job="api", method="GET",  path="/users",  code="200"} 1500
http_requests_total{job="api", method="POST", path="/users",  code="201"} 320
http_requests_total{job="api", method="GET",  path="/orders", code="500"} 12

# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{job="api", le="0.1"}  1200
http_request_duration_seconds_bucket{job="api", le="0.25"} 1500
http_request_duration_seconds_bucket{job="api", le="0.5"}  1780
http_request_duration_seconds_bucket{job="api", le="+Inf"} 1832
http_request_duration_seconds_count{job="api"} 1832
http_request_duration_seconds_sum{job="api"}   310.5

# TYPE node_memory_MemFree_bytes gauge
node_memory_MemFree_bytes{instance="node-1:9100"} 7.2e9
node_memory_MemFree_bytes{instance="node-2:9100"} 5.9e9
```

Notas que importan:

- **No existe** `http_request_total` (singular). El nombre correcto termina en `_total`.
- **No existe** la label `endpoint`; es `path`.
- `node_memory_MemFree_bytes` es un **gauge**.
