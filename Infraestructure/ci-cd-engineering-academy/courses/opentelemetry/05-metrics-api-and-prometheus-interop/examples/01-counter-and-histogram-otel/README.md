# Example 01 — Counter + Histogram + ObservableGauge con OTel

## Qué muestra

Un `MeterProvider` configurado con `ConsoleMetricExporter` y un `PeriodicExportingMetricReader` cada 1 s. La app crea tres instruments y genera tráfico simulado durante 3 s para que haya al menos dos ciclos de export.

## Cómo correr

```bash
bash run.sh
```

Si faltan dependencias OTel, el script termina con `SKIP`.

## Qué observar en la salida

- Bloques JSON con `scope_metrics` → `metrics[]`.
- Un `name` por instrument: `http.server.requests`, `http.server.duration`, `myapp.queue.depth`.
- En `http.server.duration` aparece `bucket_counts`, `explicit_bounds`, `sum`, `count` — es la aggregation por default `ExplicitBucketHistogramAggregation`.
- `aggregation_temporality: 2` (CUMULATIVE) en los contadores — es el default y lo que Prometheus espera.
- El `ObservableGauge` reporta el valor leído por el callback **en el momento del export**, no cuando lo cambiaste.
