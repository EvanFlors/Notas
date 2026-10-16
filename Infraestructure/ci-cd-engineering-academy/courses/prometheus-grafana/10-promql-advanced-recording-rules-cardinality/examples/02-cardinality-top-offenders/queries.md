# Queries diagnósticas de cardinalidad

## 1. Top métricas por nº de series

```promql
topk(10, count by (__name__)({__name__!=""}))
```

## 2. Top labels por métrica sospechosa

Sustituye `<METRIC>` y `<LABEL>` por los valores identificados:

```promql
count by (<LABEL>) (<METRIC>)
```

Ejemplos típicos:

```promql
count by (user_id) (my_app_requests_total)
count by (path)    (http_requests_total)
count by (status)  (http_requests_total)
```

## 3. Crecimiento de series (health check continuo)

```promql
# Series añadidas por segundo (5m window)
rate(prometheus_tsdb_head_series_created_total[5m])

# Delta neto
rate(prometheus_tsdb_head_series_created_total[5m])
  -
rate(prometheus_tsdb_head_series_removed_total[5m])
```

## 4. Métricas internas de salud

```promql
prometheus_tsdb_head_series
prometheus_tsdb_head_chunks
prometheus_tsdb_wal_corruptions_total
prometheus_target_scrape_pool_exceeded_target_limit_total
process_resident_memory_bytes{job="prometheus"}
```

## 5. Reglas lentas

```promql
topk(5, prometheus_rule_evaluation_duration_seconds)
topk(5, prometheus_rule_evaluation_failures_total)
```

## 6. Endpoint HTTP (sin PromQL)

```bash
curl -s http://localhost:9090/api/v1/status/tsdb | jq .
```

Secciones de interés:

- `data.seriesCountByMetricName`
- `data.labelValueCountByLabelName`
- `data.memoryInBytesByLabelName`
- `data.seriesCountByLabelValuePair`
