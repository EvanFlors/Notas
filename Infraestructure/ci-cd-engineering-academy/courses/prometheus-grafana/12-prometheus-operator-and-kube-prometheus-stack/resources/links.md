# Recursos — obs-12

## Oficial

- Prometheus Operator — https://prometheus-operator.dev/
- Prometheus Operator API reference — https://prometheus-operator.dev/docs/api-reference/api/
- `kube-prometheus-stack` (Helm chart) — https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- `kube-prometheus` (upstream) — https://github.com/prometheus-operator/kube-prometheus
- `kubernetes-mixin` — https://github.com/kubernetes-monitoring/kubernetes-mixin
- Alertmanager docs — https://prometheus.io/docs/alerting/latest/configuration/

## CRDs clave

- `ServiceMonitor` — https://prometheus-operator.dev/docs/api-reference/api/#monitoring.coreos.com/v1.ServiceMonitor
- `PodMonitor` — https://prometheus-operator.dev/docs/api-reference/api/#monitoring.coreos.com/v1.PodMonitor
- `Probe` — https://prometheus-operator.dev/docs/api-reference/api/#monitoring.coreos.com/v1.Probe
- `ScrapeConfig` — https://prometheus-operator.dev/docs/api-reference/api/#monitoring.coreos.com/v1alpha1.ScrapeConfig
- `PrometheusRule` — https://prometheus-operator.dev/docs/api-reference/api/#monitoring.coreos.com/v1.PrometheusRule
- `AlertmanagerConfig` — https://prometheus-operator.dev/docs/api-reference/api/#monitoring.coreos.com/v1alpha1.AlertmanagerConfig

## Grafana + dashboards as code

- `k8s-sidecar` (el sidecar que carga ConfigMaps) — https://github.com/kiwigrid/k8s-sidecar
- Grafana dashboard provisioning — https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards
- `grafonnet` — https://github.com/grafana/grafonnet
- `grizzly` — https://github.com/grafana/grizzly

## GitOps

- Argo CD + Helm — https://argo-cd.readthedocs.io/en/stable/user-guide/helm/
- Argo CD + CRDs best practices — https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications

## SLO / burn-rate

- Google SRE Workbook — Alerting on SLOs — https://sre.google/workbook/alerting-on-slos/
- Sloth — https://sloth.dev/
- OpenSLO — https://openslo.com/

## Troubleshooting

- "ServiceMonitor not scraped" checklist — https://prometheus-operator.dev/docs/user-guides/getting-started/#troubleshooting
- Prometheus `/service-discovery` doc — https://prometheus.io/docs/prometheus/latest/configuration/https/#service-discovery

## Charlas / lecturas

- Frederic Branczyk — "Prometheus Operator: Deep Dive" (KubeCon)
- Richard Hartmann — "Monitoring Kubernetes with Prometheus"
- Björn Rabenstein — "The Evolution of the Prometheus TSDB"
