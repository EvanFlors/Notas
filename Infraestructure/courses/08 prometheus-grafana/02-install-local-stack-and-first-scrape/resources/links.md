# Recursos — obs-02

## Documentación oficial

- Prometheus — [Getting Started](https://prometheus.io/docs/prometheus/latest/getting_started/)
- Prometheus — [Configuration (`prometheus.yml`)](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- Prometheus — [Exposition formats (`/metrics`)](https://prometheus.io/docs/instrumenting/exposition_formats/)
- Prometheus — [HTTP API](https://prometheus.io/docs/prometheus/latest/querying/api/) y endpoints `/-/healthy`, `/-/ready`, `/-/reload`.
- node_exporter — [README](https://github.com/prometheus/node_exporter) y lista de colectores por defecto.
- Grafana — [Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/) (datasources, dashboards, alerting).
- Grafana — [Data sources: Prometheus](https://grafana.com/docs/grafana/latest/datasources/prometheus/).
- Grafana — [Configure Grafana (env vars `GF_*`)](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/).

## Imágenes oficiales

- [`prom/prometheus`](https://hub.docker.com/r/prom/prometheus)
- [`grafana/grafana`](https://hub.docker.com/r/grafana/grafana) y [`grafana/grafana-oss`](https://hub.docker.com/r/grafana/grafana-oss)
- [`prom/node-exporter`](https://hub.docker.com/r/prom/node-exporter)

## OpenMetrics y texto exposition

- [OpenMetrics spec](https://openmetrics.io/)
- [Writing exporters guide](https://prometheus.io/docs/instrumenting/writing_exporters/)

## Lecturas de apoyo

- Grafana Labs — *"How to monitor a Linux server with Prometheus and Grafana"* (post en el blog oficial — base para los dashboards que usaremos en `obs-08`).
- CNCF — *"Observability landscape"* para situar Prometheus/Grafana dentro del ecosistema.
- Brendan Gregg — *USE Method* (relevante al interpretar `node_exporter`).

## Siguiente módulo

- `obs-03-metric-types-and-naming` — ya con stack arriba, se enfoca en *qué* medir y cómo nombrarlo.
