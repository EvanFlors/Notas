# Recursos — obs-07 Instrumentation with Python

## Documentación oficial

- `prometheus_client` (GitHub): https://github.com/prometheus/client_python
- Guía de instrumentación: https://prometheus.io/docs/practices/instrumentation/
- Naming conventions: https://prometheus.io/docs/practices/naming/
- Histogram vs Summary: https://prometheus.io/docs/practices/histograms/
- Multiprocess mode docs: https://prometheus.github.io/client_python/multiprocess/
- Exposition formats (text + OpenMetrics): https://prometheus.io/docs/instrumenting/exposition_formats/

## Ecosistema FastAPI / ASGI

- FastAPI middleware: https://fastapi.tiangolo.com/tutorial/middleware/
- Starlette routing (templated paths): https://www.starlette.io/routing/
- `prometheus-fastapi-instrumentator` (alternativa opinada): https://github.com/trallnag/prometheus-fastapi-instrumentator

## Cardinalidad y buenas prácticas

- "Prometheus labels and cardinality" (Grafana Labs): https://grafana.com/blog/2022/02/15/avoiding-high-cardinality-with-prometheus/
- "Cardinality is king" (Robust Perception): https://www.robustperception.io/cardinality-is-key
- "How many metrics is too many" (Chronosphere): https://chronosphere.io/learn/why-high-cardinality-metrics-break-your-observability/

## Exemplars y correlación con traces

- Exemplars en Prometheus: https://prometheus.io/docs/prometheus/latest/feature_flags/#exemplars-storage
- Exemplars en Grafana: https://grafana.com/docs/grafana/latest/fundamentals/exemplars/
- OpenTelemetry Python: https://opentelemetry.io/docs/languages/python/

## Multiproceso con gunicorn/uwsgi

- Gunicorn settings: https://docs.gunicorn.org/en/stable/settings.html
- Uvicorn workers class: https://www.uvicorn.org/#running-with-gunicorn
- Discusión de `child_exit` y `mark_process_dead`: https://github.com/prometheus/client_python/issues/568

## Métodos de diseño

- RED method (Tom Wilkie): https://thenewstack.io/monitoring-microservices-red-method/
- USE method (Brendan Gregg): https://www.brendangregg.com/usemethod.html
- Google SRE Workbook — SLOs: https://sre.google/workbook/implementing-slos/
