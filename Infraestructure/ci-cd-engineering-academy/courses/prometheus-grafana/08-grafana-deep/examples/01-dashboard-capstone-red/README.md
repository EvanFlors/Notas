# Ejemplo 01 — Dashboard RED del capstone

Dashboard de ejemplo con **Rate / Errors / Duration** para una API HTTP, provisionado desde YAML.

## Qué muestra
- `time series` — rate de requests por `handler`.
- `stat` — error rate global (ratio 5xx / total).
- `gauge` — latencia p95 actual.
- `heatmap` — distribución de latencia (buckets de histogram).
- `table` — top 10 handlers por latencia p95.
- `state timeline` — `up` por target.

Las métricas vienen de `node_exporter` + métricas sintéticas que genera el propio Prometheus (`prometheus_http_requests_total`, `prometheus_http_request_duration_seconds_bucket`). No necesitas instrumentar nada.

## Levantar
```bash
cd examples/01-dashboard-capstone-red
docker compose up -d
# Grafana: http://localhost:3000  (admin / admin)
# Prometheus: http://localhost:9090
```

Entra a Grafana → *Dashboards* → *Capstone* → *RED — capstone (demo)*. Verás el badge **Provisioned**.

## Qué estudiar en el JSON
- `uid` fijo del dashboard (`capstone-red-demo`) — permite enlazar paneles.
- `templating.list` — variable `job` tipo `query`.
- Cada panel usa `$__rate_interval` en los `rate()` para evitar `NaN` con zooms cortos.
- `fieldConfig.overrides` en el `time series` pinta p95 en rojo.

## Parar
```bash
docker compose down -v
```
