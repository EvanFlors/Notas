# Comparativa — Classic vs Native histogram

## Resumen de 1 línea

> Native = 1 serie sparse por histogram; classic = N series (una por `le`) + `_count` + `_sum`.

## Costo en series

Para un histogram de latencia con 10 buckets, expuesto por 20 instancias con 5 endpoints:

- **Classic**: `10 (buckets) × 20 × 5 + 20 × 5 (_count) + 20 × 5 (_sum)` = 1 200 series.
- **Native**: `1 × 20 × 5` = 100 series.

Factor **~12×** de ahorro en este caso típico.

## Compatibilidad PromQL

```promql
# Clásico (sigue funcionando como siempre):
histogram_quantile(0.99,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)

# Native (misma función, sin sufijo _bucket, sin by (le)):
histogram_quantile(0.99, rate(http_request_duration_seconds[5m]))
```

## Semánticas que native habilita

- Suma de histograms correcta cross-serie (`sum(rate(…[5m]))`) sin perder la distribución.
- Resolución fina y adaptable (`schema` 0..8).
- Agregación eficiente en long-term store (Mimir/VictoriaMetrics lo aprovechan).

## Qué no cambia

- Native histograms siguen siendo **histogram** semánticamente — no son summaries. Las agregaciones siguen siendo matemáticamente correctas.
- `rate()` sobre native histogram devuelve un native rate histogram.
