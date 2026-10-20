# Recursos — `cap-11-observability-prom-grafana-otel-loki-slo`

## Documentacion oficial

- **Prometheus Operator** — https://prometheus-operator.dev/
- **kube-prometheus-stack chart** — https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- **ServiceMonitor CRD** — https://prometheus-operator.dev/docs/user-guides/getting-started/
- **PrometheusRule CRD** — https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.PrometheusRule
- **Alertmanager config** — https://prometheus.io/docs/alerting/latest/configuration/
- **PromQL cheatsheet** — https://promlabs.com/promql-cheat-sheet/
- **Grafana dashboards JSON model** — https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/view-dashboard-json-model/
- **OpenTelemetry Collector** — https://opentelemetry.io/docs/collector/
- **OpenTelemetry Collector Helm chart** — https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-collector
- **OpenTelemetry Python SDK** — https://opentelemetry.io/docs/languages/python/
- **FastAPI instrumentation** — https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/fastapi/fastapi.html
- **Grafana Loki** — https://grafana.com/docs/loki/latest/
- **Grafana Tempo** — https://grafana.com/docs/tempo/latest/

## SLO / SRE

- **Google SRE Workbook — Alerting on SLOs** — https://sre.google/workbook/alerting-on-slos/
- **Multi-window multi-burn-rate paper (Jack Neely, 2020)** — https://research.google/pubs/pub48317/
- **Pyrra (SLOs on top of Prometheus Operator)** — https://github.com/pyrra-dev/pyrra
- **Sloth (SLO generator)** — https://github.com/slok/sloth
- **openslo spec** — https://openslo.com/

## Herramientas de validacion local

- **promtool** — https://prometheus.io/docs/prometheus/latest/command-line/promtool/
- **amtool** — https://github.com/prometheus/alertmanager#amtool
- **yq (mikefarah)** — https://mikefarah.gitbook.io/yq/
- **helm template** — https://helm.sh/docs/helm/helm_template/

## Lecturas

- **Rob Ewaschuk — Philosophy on Alerting** (Google SRE book annex)
- **Charity Majors — "Observability vs Monitoring"** — https://charity.wtf/2020/03/03/observability-is-a-many-splendored-definition/
- **Cindy Sridharan — Distributed Systems Observability** (O'Reilly, 2018)

## Siguiente lectura (anticipo Etapa 12)

- **Kyverno** — https://kyverno.io/
- **External Secrets Operator** — https://external-secrets.io/latest/
- **Falco** — https://falco.org/docs/
