# Recursos — PromQL fundamentos

## Documentación oficial

- Prometheus — Querying basics: <https://prometheus.io/docs/prometheus/latest/querying/basics/>
- Prometheus — Operators: <https://prometheus.io/docs/prometheus/latest/querying/operators/>
- Prometheus — Functions: <https://prometheus.io/docs/prometheus/latest/querying/functions/>
- Prometheus — Examples: <https://prometheus.io/docs/prometheus/latest/querying/examples/>
- `histogram_quantile` detalle: <https://prometheus.io/docs/practices/histograms/>

## Herramientas

- `promtool` (incluida en el release de Prometheus): <https://prometheus.io/docs/prometheus/latest/command-line/promtool/>
- Prometheus UI local (`/graph`): sitio ideal para experimentar antes de pegar la query en Grafana.
- PromLens (herramienta visual, descontinuada como SaaS pero el fork OSS sigue útil): <https://github.com/prometheus/promlens>

## Lectura recomendada

- *RED Method* — Tom Wilkie: <https://www.weave.works/blog/the-red-method-key-metrics-for-microservices-architecture/>
- *USE Method* — Brendan Gregg: <https://www.brendangregg.com/usemethod.html>
- *How NOT to measure latency* — Gil Tene: <https://www.youtube.com/watch?v=lJ8ydIuPFeU> (motiva histogramas vs summaries).

## Cheat-sheets

- PromQL Cheat Sheet (Grafana Labs): <https://grafana.com/blog/2020/02/04/introduction-to-promql-the-prometheus-query-language/>
- PromQL for Humans (Timber): <https://timber.io/blog/promql-for-humans/>

## Vídeo

- PromQL Deep Dive (PromCon): buscar la charla anual más reciente en el canal de CNCF/PromCon.

## Relación con el curso

- Base para `obs-07-instrumentation-with-python` (una vez instrumentada la app, estas queries la "ven").
- Base para `obs-09-alertmanager-and-alert-design` (la expresión del alerting rule es PromQL).
- Profundización en `obs-10-promql-advanced-recording-rules-cardinality`.
- Core del lenguaje de SLO en `obs-14-slo-and-burn-rate-alerts`.
