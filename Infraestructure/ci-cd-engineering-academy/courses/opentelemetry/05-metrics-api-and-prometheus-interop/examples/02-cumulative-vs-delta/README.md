# Example 02 — Cumulative vs Delta temporality

## Qué muestra

Dos `MeterProvider` idénticos excepto por el `preferred_temporality` de su `ConsoleMetricExporter`: uno emite `CUMULATIVE`, otro `DELTA`. Se incrementa el **mismo** patrón de `Counter` en ambos y se observa cómo difieren los exports.

## Cómo correr

```bash
bash run.sh
```

## Qué observar

Buscar en la salida la línea `aggregation_temporality` dentro de cada métrica `demo.events`:

- `aggregation_temporality: 2` → **CUMULATIVE**. Los valores crecen export tras export (10, 20, 30…).
- `aggregation_temporality: 1` → **DELTA**. Los valores reportan solo el delta desde el último export (10, 10, 10…).

## Por qué importa

- Prometheus asume **cumulative**. Si exportas `DELTA` a Prometheus, `rate()` queda plano o alterna irregularmente.
- StatsD / Datadog asumen **delta**. Si exportas `CUMULATIVE` ves "contadores que nunca bajan".
- Si en la frontera del pipeline hace falta cambiar temporalidad, el **Collector** tiene los processors `cumulativetodelta` y `deltatocumulative`.
