# Recursos — obs-15 Platform observability

## Dashboards as code
- `grafonnet` (jsonnet) — https://github.com/grafana/grafonnet
- `grizzly` CLI — https://github.com/grafana/grizzly
- `dashboard-linter` — https://github.com/grafana/dashboard-linter
- Terraform provider Grafana — https://registry.terraform.io/providers/grafana/grafana/latest/docs
- `grafanalib` (Python) — https://github.com/weaveworks/grafanalib
- `kubernetes-mixin` (ejemplo real de dashboards+alerts jsonnet) — https://github.com/kubernetes-monitoring/kubernetes-mixin

## Alerts as code
- `promtool test rules` — https://prometheus.io/docs/prometheus/latest/configuration/unit_testing_rules/
- Prometheus Operator `PrometheusRule` CRD — https://prometheus-operator.dev/docs/user-guides/alerting/
- `pint` (Cloudflare) linter de reglas — https://github.com/cloudflare/pint
- Awesome Prometheus Alerts — https://samber.github.io/awesome-prometheus-alerts/

## SLOs y burn-rate
- Google SRE Workbook, cap. "Alerting on SLOs" — https://sre.google/workbook/alerting-on-slos/
- `sloth` — https://sloth.dev/
- OpenSLO — https://openslo.com/

## Gobernanza y plataforma
- Backstage software templates — https://backstage.io/docs/features/software-templates/
- Grafana folders & RBAC — https://grafana.com/docs/grafana/latest/administration/roles-and-permissions/
- Alertmanager routing — https://prometheus.io/docs/alerting/latest/configuration/
- PagerDuty Events API v2 — https://developer.pagerduty.com/docs/events-api-v2/overview/
- Opsgenie Alert API — https://docs.opsgenie.com/docs/alert-api

## Costo y meta-observabilidad
- Grafana Cloud pricing (referencia 2026) — https://grafana.com/pricing/
- Charity Majors — "The Future of Observability" talks — https://charity.wtf/
- Honeycomb "Observability Engineering" (O'Reilly) — libro completo
- "Cost of Observability" posts (Grafana, Datadog blogs)
- Cardinality troubleshooting — https://prometheus.io/docs/practices/instrumentation/#use-labels

## IDP / Backstage
- Backstage — https://backstage.io/
- Port — https://www.getport.io/
- CNOE — https://cnoe.io/

## Lectura recomendada antes de la actividad 02
- Grafana Mimir cost estimation docs
- VictoriaMetrics `vmagent`/`vminsert` sizing guides
- Loki best practices (labels, chunk size) — https://grafana.com/docs/loki/latest/best-practices/
