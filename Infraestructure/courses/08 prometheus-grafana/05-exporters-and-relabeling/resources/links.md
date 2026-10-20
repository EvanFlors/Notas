# Recursos — obs-05

> A re-verificar en Fase 4 de contenido. Priorizar documentación oficial.

## Documentación oficial

- Prometheus — Configuration (`prometheus.yml`): https://prometheus.io/docs/prometheus/latest/configuration/configuration/
- Prometheus — Relabeling guide (reference de todas las acciones): https://prometheus.io/docs/prometheus/latest/configuration/configuration/#relabel_config
- Prometheus — `metric_relabel_configs`: https://prometheus.io/docs/prometheus/latest/configuration/configuration/#metric_relabel_configs
- Prometheus — Exporter list oficial + de terceros: https://prometheus.io/docs/instrumenting/exporters/
- Writing exporters (best practices): https://prometheus.io/docs/instrumenting/writing_exporters/

## Exporters mencionados

- `node_exporter`: https://github.com/prometheus/node_exporter
- `cAdvisor`: https://github.com/google/cadvisor
- `blackbox_exporter`: https://github.com/prometheus/blackbox_exporter
- `mysqld_exporter`: https://github.com/prometheus/mysqld_exporter
- `postgres_exporter`: https://github.com/prometheus-community/postgres_exporter
- `redis_exporter`: https://github.com/oliver006/redis_exporter
- `nginx-prometheus-exporter`: https://github.com/nginx/nginx-prometheus-exporter
- `snmp_exporter`: https://github.com/prometheus/snmp_exporter
- `cloudwatch_exporter`: https://github.com/prometheus/cloudwatch_exporter

## Lecturas complementarias

- Robust Perception blog — "Life of a Label" (cómo viaja un label por el pipeline relabel): https://www.robustperception.io/life-of-a-label
- Grafana Labs — Reducing Prometheus cardinality: https://grafana.com/blog/2022/10/20/how-to-manage-high-cardinality-metrics-in-a-prometheus-environment/
- Promlabs tutoriales — Understanding relabeling: https://promlabs.com/blog/2022/03/09/relabeling-deep-dive/
- Brian Brazil — *Prometheus: Up & Running* (O'Reilly), capítulos 7 (Exporters) y 8 (Relabeling).

## Herramientas útiles

- `promtool check config prometheus.yml` — valida sintaxis antes de recargar.
- UI `/service-discovery` del propio Prometheus — muestra labels pre/post relabel.
- UI `/targets` — estado `up/down` + último error de scrape.
- `promtool debug all <job>` para dumps completos.
