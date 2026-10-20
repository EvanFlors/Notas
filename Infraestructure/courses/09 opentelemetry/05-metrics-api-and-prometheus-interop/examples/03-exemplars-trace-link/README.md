# Example 03 — Exemplars (métrica ↔ trace)

## Qué muestra

El histograma `work.duration` se graba **dentro de un span activo**. El SDK adjunta automáticamente un exemplar con `trace_id` y `span_id` al bucket correspondiente, visible en el output del `ConsoleMetricExporter`.

## Cómo correr

```bash
bash run.sh
```

## Qué observar

Buscar en el JSON de la métrica `work.duration` el campo `exemplars` dentro de `data_points`. Cada exemplar tiene:

- `trace_id` — el mismo que figura en el span exportado por `ConsoleSpanExporter`.
- `span_id` — idem.
- `value` — la muestra concreta.
- `time_unix_nano` — momento del `record()`.

## Por qué importa

- Un dashboard Grafana sobre esta métrica puede dibujar puntos (los exemplars) y permitir **click-through** al trace completo en Tempo/Jaeger.
- No hace falta tocar la app para añadirlos: basta con grabar la métrica dentro de un span.
- Prometheus necesita `--enable-feature=exemplar-storage` para persistirlos y Grafana requiere `exemplarTraceIdDestinations` configurado en el datasource.
