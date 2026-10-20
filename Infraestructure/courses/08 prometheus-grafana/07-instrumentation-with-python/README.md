# obs-07 — Instrumentation with Python

## Identificación
- **ID:** `obs-07-instrumentation-with-python`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `obs-03-metric-types-and-naming`, `obs-04-promql-fundamentals`

## Objetivo
Instrumentar una aplicación Python (FastAPI/Starlette) con `prometheus_client` siguiendo buenas prácticas de naming, cardinalidad y exposición, de modo que un Prometheus scrapee `/metrics` y las métricas sirvan para dashboards RED y alertas.

## Temas y subtemas
- Librería `prometheus_client`: `Counter`, `Gauge`, `Histogram`, `Summary`.
- Default collectors (`process_*`, `python_gc_*`, `python_info`).
- Exposición: `start_http_server` (standalone), WSGI/ASGI (`make_asgi_app`), integración con FastAPI/Starlette.
- Middleware RED (Rate, Errors, Duration) en el borde del servicio.
- Labels dinámicos y disciplina de cardinalidad (nunca `user_id`, `request_id`, `email`).
- Exemplars (vínculo métrica ↔ trace span).
- `multiprocess` mode para gunicorn/uwsgi (procesos múltiples → métricas agregadas vía directorio).
- Testing con `REGISTRY.collect()` (sin necesidad de levantar HTTP).
- Buenas prácticas de unidades (`_seconds`, `_bytes`, `_total`) y naming consistente.

## Conceptos internos (fundamentos)
- Cada combinación única de valores de labels crea **una serie nueva** en Prometheus. Instrumentar es un acto de diseño: cada label es un acuerdo con tu operador.
- `Histogram` guarda buckets acumulativos + `_sum` + `_count` → agregable cross-instance y correcto con `histogram_quantile()`.
- `Summary` calcula cuantiles en el proceso → **no es agregable** entre instancias; preferir histogram salvo caso justificado.
- En multiproceso, el registry en memoria del worker no es compartido. `prometheus_client` persiste archivos `.db` por proceso en `PROMETHEUS_MULTIPROC_DIR` y los une en el scrape.
- `REGISTRY.collect()` devuelve `MetricFamily` iterables: la base para tests sin red.

## Competencias
- **Conceptual:** justificar la elección de tipo y labels; explicar por qué `path` templatizado sí y `request_id` no.
- **Operativa:** exponer `/metrics` en FastAPI y verificar scrape; configurar modo multiproceso con gunicorn.
- **Arquitectónica:** diseñar un contrato de métricas (naming, labels, unidades) para un servicio del capstone.

## Ejemplos
- [`examples/01-counter-and-histogram-in-fastapi`](examples/01-counter-and-histogram-in-fastapi/) — primer `/metrics` instrumentado en FastAPI.
- [`examples/02-middleware-red-metrics`](examples/02-middleware-red-metrics/) — middleware ASGI con RED.
- [`examples/03-multiprocess-mode`](examples/03-multiprocess-mode/) — modo multiproceso con gunicorn.

## Actividades
- [`activities/01-instrument-capstone`](activities/01-instrument-capstone/) — guided-lab para instrumentar el servicio del capstone con RED metrics.
- [`activities/02-cardinality-safe-labels`](activities/02-cardinality-safe-labels/) — independent: auditar y corregir una app con labels peligrosos.

## Entregables
- App del capstone con `/metrics` expuesto, RED metrics correctas y tests que validan la existencia de las métricas.
- Script o notas que documenten las decisiones de naming/labels.

## Criterios de evaluación
- **Conceptual:** diferenciar cuándo usar Counter/Histogram/Gauge y por qué.
- **Operativa:** scrape exitoso desde curl y desde Prometheus; sin cardinality explosion en los labels usados.
- **Arquitectónica:** proponer y defender el contrato de métricas y la estrategia multiproceso.

## Recursos
Ver [`resources/links.md`](resources/links.md).
