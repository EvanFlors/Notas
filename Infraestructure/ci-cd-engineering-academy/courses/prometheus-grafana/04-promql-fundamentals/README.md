# obs-04-promql-fundamentals — PromQL: fundamentos

## Identificación

- **ID:** `obs-04-promql-fundamentals`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** `obs-03-metric-types-and-naming`

## Objetivo

Leer y escribir PromQL con confianza: elegir el tipo de expresión correcto, aplicar funciones de forma matemáticamente válida sobre counters/gauges/histograms, agregar sin perder dimensionalidad útil y depurar queries vacías.

## Temas y subtemas

1. **Tipos de expresión**: instant vector, range vector, scalar, string.
2. **Selectors**: `=`, `!=`, `=~`, `!~`; `{job="x", instance=~".*api.*"}`.
3. **Ventanas de tiempo**: `[5m]`, `[1h]`.
4. **Modificadores temporales**: `offset 1h`, `@ <unix_ts>`, `@ start()`, `@ end()`.
5. **Funciones sobre counters**: `rate`, `irate`, `increase`.
6. **Funciones sobre gauges**: `avg_over_time`, `max_over_time`, `min_over_time`, `sum_over_time`, `deriv`, `predict_linear`, `clamp_min`, `clamp_max`, `absent`.
7. **Agregadores**: `sum`, `avg`, `max`, `min`, `count`, `stddev`, `topk`, `bottomk` con `by (...)` / `without (...)`.
8. **Histogramas**: `histogram_quantile` sobre buckets.
9. **Operadores binarios y matching**: aritméticos, comparación, lógicos; `on(...)`, `ignoring(...)`, `group_left`, `group_right`.
10. **Subqueries**: `expr[5m:1m]`.
11. **`rate` vs `irate` vs `increase`** y anti-patrones (`rate()` sobre gauge, `delta()` sobre counter).
12. **Depurar queries vacías** y errores comunes.

## Conceptos internos (fundamentos)

- `rate()` necesita **≥ 2 muestras** en la ventana; ventanas más cortas que `~4 × scrape_interval` producen `NaN` esporádicos.
- `increase()` es azúcar sintáctico de `rate() × seconds(range)`.
- `irate()` usa las dos últimas muestras: útil para gráficos interactivos, pésimo para alertas (reacciona a cualquier spike puntual).
- Un **histogram** se compone de series `_bucket`, `_count`, `_sum`. `histogram_quantile(0.95, sum by (le, job) (rate(http_request_duration_seconds_bucket[5m])))` siempre incluye `le` en el `by`.
- Las **subqueries** son costosas: Prometheus evalúa el inner query en cada paso del outer. Si una expresión se consume en N dashboards + M alertas, muévela a **recording rule**.
- Una query vacía casi siempre se explica por una de 4 causas: nombre de métrica incorrecto, label incorrecto, no hay datos en el rango, o aplicación de función inválida (p. ej. `rate()` sobre gauge → serie monotónica falsa).

## Competencias

- **Conceptual**: distinguir cuándo una expresión es matemáticamente válida (`rate` requiere counter, `avg_over_time` requiere gauge).
- **Operativa**: componer queries RED (Rate / Errors / Duration) para un servicio HTTP y verlas en Prometheus UI.
- **Arquitectónica**: identificar qué queries merecen una recording rule por costo o reuso.

## Ejemplos

- [`examples/01-rate-increase-irate`](examples/01-rate-increase-irate/) — comparación lado a lado sobre el mismo counter.
- [`examples/02-aggregation-by-without`](examples/02-aggregation-by-without/) — cómo `by` y `without` cambian el resultado.
- [`examples/03-histogram-quantile`](examples/03-histogram-quantile/) — p50/p95/p99 correctos a partir de buckets.

## Actividades

- [`activities/01-build-red-queries`](activities/01-build-red-queries/) — *guided-lab*: construir el trio RED del capstone.
- [`activities/02-fix-empty-query`](activities/02-fix-empty-query/) — *independent debug*: 5 queries que devuelven vacío; diagnosticar y arreglar.

## Entregables

Un cuaderno (`activities/01-build-red-queries/solution/queries.promql`) con las queries RED del capstone validadas con `promtool check rules` cuando esté disponible.

## Criterios de evaluación

| Dimensión | Qué se espera |
|-----------|----------------|
| Conceptual | Explicar por qué `rate()` sobre un gauge es inválido, y por qué `histogram_quantile` necesita `le` en el `by`. |
| Operativa | Escribir las 3 queries RED para un servicio HTTP a partir de un `/metrics` dado. |
| Arquitectónica | Identificar al menos una query que merece recording rule y justificar. |

## Recursos

Ver [`resources/links.md`](resources/links.md).
