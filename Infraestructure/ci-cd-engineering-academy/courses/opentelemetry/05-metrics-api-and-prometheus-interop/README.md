# otel-05 — Metrics API and Prometheus Interop

## Identificación
- **ID:** `otel-05-metrics-api-and-prometheus-interop`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `otel-04-instrumenting-python-traces`, curso **prometheus-grafana** `obs-07-instrumentation-with-python`

## Objetivo
Emitir métricas desde una aplicación Python usando la **API de métricas de OpenTelemetry** y entender cómo esas métricas interoperan con **Prometheus** (temporalidad, vistas, exporters, exemplars) para poder migrar progresivamente desde `prometheus_client` sin perder observabilidad.

## Temas y subtemas
- **MeterProvider** y **Meter** (análogos a TracerProvider/Tracer).
- **Instruments** síncronos: `Counter`, `UpDownCounter`, `Histogram`.
- **Instruments asíncronos** (callbacks `observe`): `ObservableCounter`, `ObservableGauge`, `ObservableUpDownCounter`.
- **Temporality**: `CUMULATIVE` (compatible con Prometheus) vs `DELTA` (compatible con StatsD/Datadog).
- **Aggregation** por default por tipo de instrument; **Views** para redefinir aggregation o buckets de histograma.
- Pipeline de export: **OTLP → Collector → Prometheus** (vía `prometheusreceiver` o OTLP ingest nativo en Prometheus ≥ v2.47 / v3.x).
- **PrometheusMetricReader**: exposición directa `/metrics` para scrape (sin Collector).
- **Exemplars**: vincular una muestra de métrica con el `trace_id` que la produjo.
- Comparación con `prometheus_client`: cuándo migrar, cuándo coexistir, cuándo **no** migrar.
- Antipatrón: emitir la misma métrica desde dos librerías a la vez.

## Conceptos internos (fundamentos)
- **Temporalidad** es el *gotcha* que primero rompe en producción: Prometheus asume contadores **cumulativos** monotónicos; si el SDK exporta `delta`, un `rate()` queda plano o errático. Para interop con Prom: `AggregationTemporality.CUMULATIVE` siempre.
- Un **Counter** OTel exportado a Prometheus se mapea a un `*_total`; un **Histogram** OTel se mapea a `*_bucket` + `_sum` + `_count`. Los nombres se **normalizan** (puntos → underscores, se añade `_total`).
- Los **Views** son filtros declarativos en el SDK que permiten cambiar aggregation (por ejemplo redefinir los buckets de un Histogram) sin tocar el código de la app.
- Los **callbacks** de instruments observables se ejecutan **en cada export**, no cuando los llamas. Útil para medir queue size, memoria, etc.
- Los **exemplars** se adjuntan automáticamente a buckets de histograma cuando el proceso tiene un span activo: Grafana los dibuja como puntos en la gráfica y permite click-through al trace.

## Competencias
- **Conceptual:** justificar cuándo usar cada instrument y por qué `cumulative` es la temporalidad por default para Prom.
- **Operativa:** instrumentar una app Python con OTel metrics; configurar un reader Prometheus directo y/o OTLP; verificar exemplars.
- **Arquitectónica:** decidir si una app nueva usa OTel o `prometheus_client`; planificar la migración gradual sin doble emisión.

## Ejemplos
- [`examples/01-counter-and-histogram-otel`](examples/01-counter-and-histogram-otel/) — crear Meter, Counter y Histogram, exportar a consola.
- [`examples/02-cumulative-vs-delta`](examples/02-cumulative-vs-delta/) — mismo contador con dos readers configurados en temporalidad distinta.
- [`examples/03-exemplars-trace-link`](examples/03-exemplars-trace-link/) — emitir un histograma dentro de un span y mostrar el `trace_id` adjunto como exemplar.

## Actividades
- [`activities/01-migrate-prometheus-client-to-otel`](activities/01-migrate-prometheus-client-to-otel/) — **guided-lab**: convertir un servicio Flask desde `prometheus_client` hacia la API de métricas de OTel manteniendo `/metrics` scrapeable.
- [`activities/02-add-exemplars`](activities/02-add-exemplars/) — **independent**: añadir exemplars a una métrica existente y verificar que llevan `trace_id`.

## Entregables
- Servicio Flask migrado a OTel con `/metrics` compatible con Prometheus.
- Notas o ADR corto justificando temporalidad `cumulative` elegida.
- Captura (texto) del histograma con exemplars incluyendo un `trace_id`.

## Criterios de evaluación
- **Conceptual:** diferenciar `Counter`/`UpDownCounter`/`Histogram`/`Observable*`; explicar qué pasa si se cambia a temporalidad `delta` frente a Prometheus.
- **Operativa:** `/metrics` responde con el formato Prometheus esperado; los exemplars se materializan en el output.
- **Arquitectónica:** proponer plan de migración `prometheus_client` → OTel que evite doble emisión.

## Recursos
Ver [`resources/links.md`](resources/links.md).
