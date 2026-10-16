# Fix definitivo — cardinality explosion en checkout-service

## Métrica ofensora

- **Métrica:** `checkout_requests_by_user_total` (añadida en release `v2.14`).
- **Label culpable:** `user_id` — toma ~1.98 M valores únicos y crece sin cota (cada nuevo usuario = una serie nueva, forever).

## Hot-fix aplicado (temporal)

En `prometheus.yml`, dentro del `scrape_config` del `job_name: checkout-service`:

```yaml
metric_relabel_configs:
  - source_labels: [__name__]
    regex: checkout_requests_by_user_total
    action: drop
```

Esto corta el sangrado: tras reiniciar Prometheus, la métrica ya no entra a la TSDB.

Elegimos `drop` de la métrica entera (en vez de `labeldrop` sobre `user_id`) porque la métrica, sin la dimensión `user_id`, se duplica semánticamente con `http_requests_total` — no aporta señal nueva. Mantenerla sin la label sería redundante.

Añadimos además defensa en profundidad: `sample_limit: 50000` y `label_limit: 32` sobre el mismo scrape, para que la próxima vez el scrape se corte con error visible antes de romper la TSDB.

## Fix definitivo (aguas arriba, en el productor)

Eliminar la métrica del instrumentation code de `checkout-service`. En vez de "requests por usuario como label", usar:

- **Exemplars** sobre las métricas RED existentes (`http_requests_total`, `http_request_duration_seconds_*`) para que Grafana permita saltar de la métrica agregada al trace del request individual.
- **Logs estructurados** en Loki con `user_id` como campo (no como label de Loki), consultables con `{app="checkout"} | json | user_id="u_12345"`.
- **Traces** en Tempo si el detalle por usuario es para debugging; el `user_id` va en span attributes, no en métricas.

## Alerta de meta-observabilidad propuesta

```yaml
- alert: PrometheusTSDBHeadSeriesGrowing
  expr: rate(prometheus_tsdb_head_series_created_total[5m]) > 2000
  for: 10m
  annotations:
    summary: "TSDB head series growing >2k/s for 10m — investigate top metrics"
    runbook: "obs-10 §6 — topk(10, count by (__name__)({__name__!=\"\"}))"
```

Con esto habríamos detectado el problema a los ~10 min de empezar, no a los 30 cuando ya no hay vuelta.
