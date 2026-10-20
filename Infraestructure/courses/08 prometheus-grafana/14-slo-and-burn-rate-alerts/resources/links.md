# Recursos — SLOs y burn-rate alerts

## Fundamentos (lectura obligada)
- *Site Reliability Workbook* — [Capítulo 5 "Alerting on SLOs"](https://sre.google/workbook/alerting-on-slos/). Fuente canónica de la receta MWMBR.
- *Site Reliability Engineering* — Capítulo 4 "Service Level Objectives" (Google, O'Reilly).
- Google Cloud Architecture Center — [Adopting SLOs](https://cloud.google.com/architecture/adopting-slos).

## Herramientas
- **Sloth** — https://sloth.dev/ · GitHub: https://github.com/slok/sloth · Imagen: `ghcr.io/slok/sloth`.
- **OpenSLO** — spec declarativa agnóstica: https://openslo.com/ · GitHub: https://github.com/OpenSLO/OpenSLO.
- **Pyrra** — alternativa a Sloth con UI: https://github.com/pyrra-dev/pyrra.
- **promtool** — https://prometheus.io/docs/prometheus/latest/command-line/promtool/ (`check rules`, `test rules`).

## Prometheus Operator
- `PrometheusRule` CRD — https://prometheus-operator.dev/docs/operator/api/#prometheusrule.
- kube-prometheus-stack chart — https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack.

## Burn-rate math y derivaciones
- "Multi-Window, Multi-Burn-Rate Alerts" — resumen con tablas: https://sre.google/workbook/alerting-on-slos/#6-multiwindow-multi-burn-rate-alerts.
- "Implementing SLOs" (Workbook cap. 2) — https://sre.google/workbook/implementing-slos/.

## Casos de uso
- Grafana Labs — "SLOs in Grafana" blog series.
- GitLab handbook — SLOs públicos como ejemplo de ownership: https://handbook.gitlab.com/handbook/engineering/infrastructure/performance-indicators/.

## Error budget policy (plantillas)
- Google — ejemplo de policy en SRE Workbook, Appendix.
- Nobl9 — plantillas y ejemplos: https://www.nobl9.com/resources/the-art-of-slos.
