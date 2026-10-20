# Recursos — k8s-15

## Documentación oficial Kubernetes

- **metrics-server** — <https://github.com/kubernetes-sigs/metrics-server>
- **Resource Metrics API** — <https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/>
- **Events** — <https://kubernetes.io/docs/reference/kubernetes-api/cluster-resources/event-v1/>
- **cAdvisor en kubelet** — <https://github.com/google/cadvisor>

## Prometheus Operator / kube-prometheus-stack

- **Prometheus Operator** — <https://prometheus-operator.dev/>
- **CRDs** — <https://prometheus-operator.dev/docs/operator/api/>
- **kube-prometheus-stack chart** — <https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack>
- **kubernetes-mixin** — <https://github.com/kubernetes-monitoring/kubernetes-mixin>
- **kube-state-metrics** — <https://github.com/kubernetes/kube-state-metrics>
- **node-exporter** — <https://github.com/prometheus/node_exporter>

## Prometheus core

- **Documentación** — <https://prometheus.io/docs/>
- **Best practices** (naming, labels, histograms) — <https://prometheus.io/docs/practices/>
- **promtool test rules** — <https://prometheus.io/docs/prometheus/latest/configuration/unit_testing_rules/>
- **Exemplars** — <https://prometheus.io/docs/prometheus/latest/feature_flags/#exemplars-storage>

## Logs — Loki ecosystem

- **Loki** — <https://grafana.com/docs/loki/latest/>
- **Promtail** — <https://grafana.com/docs/loki/latest/send-data/promtail/>
- **Vector** — <https://vector.dev/>
- **OpenTelemetry Collector filelog receiver** — <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver>

## Traces — Tempo / Jaeger / OpenTelemetry

- **Tempo** — <https://grafana.com/docs/tempo/latest/>
- **Jaeger** — <https://www.jaegertracing.io/docs/>
- **OpenTelemetry** — <https://opentelemetry.io/docs/>
- **OpenTelemetry Operator** — <https://github.com/open-telemetry/opentelemetry-operator>
- **OpenTelemetry Collector** — <https://opentelemetry.io/docs/collector/>
- **W3C Trace Context** — <https://www.w3.org/TR/trace-context/>

## Alerting / SLO

- **Google SRE Workbook — Alerting on SLOs** — <https://sre.google/workbook/alerting-on-slos/>
- **Alertmanager** — <https://prometheus.io/docs/alerting/latest/alertmanager/>
- **Multi-window multi-burn-rate** — <https://sre.google/workbook/alerting-on-slos/#4-alert-on-burn-rate>
- **Pyrra (SLO generator)** — <https://github.com/pyrra-dev/pyrra>
- **Sloth** — <https://sloth.dev/>

## Eventos

- **kubernetes-event-exporter (resmoio)** — <https://github.com/resmoio/kubernetes-event-exporter>
- **kube-eventer (AliCloud)** — <https://github.com/AliyunContainerService/kube-eventer>

## eBPF-based observability

- **Pixie** — <https://px.dev/>
- **Cilium Hubble** — <https://docs.cilium.io/en/stable/observability/hubble/>
- **Parca (continuous profiling)** — <https://www.parca.dev/>
- **Pyroscope** — <https://grafana.com/docs/pyroscope/latest/>

## Dashboards

- **Grafana** — <https://grafana.com/docs/>
- **Dashboards oficiales K8s** (grafana.com/dashboards) — <https://grafana.com/grafana/dashboards/?dataSource=prometheus&category=kubernetes>

## Lecturas de criterio

- **Rob Ewaschuk — My Philosophy on Alerting** — <https://docs.google.com/document/d/199PqyG3UsyXlwieHaqbGiWVa8eMWi8zzAn0YfcApr8Q>
- **Brendan Gregg — USE Method** — <https://www.brendangregg.com/usemethod.html>
- **Tom Wilkie — The RED Method** — <https://thenewstack.io/monitoring-microservices-red-method/>
- **Charity Majors — Observability vs Monitoring** — <https://www.honeycomb.io/blog/observability-a-manifesto>

## Para producción (retention, HA, multi-cluster)

- **Thanos** — <https://thanos.io/>
- **Grafana Mimir** — <https://grafana.com/docs/mimir/latest/>
- **VictoriaMetrics** — <https://docs.victoriametrics.com/>
