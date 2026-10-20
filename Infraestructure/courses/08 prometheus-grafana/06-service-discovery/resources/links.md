# Recursos — obs-06 Service Discovery

## Documentación oficial

- Prometheus configuration — `<scrape_config>`:
  https://prometheus.io/docs/prometheus/latest/configuration/configuration/#scrape_config
- `kubernetes_sd_config`:
  https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config
- `ec2_sd_config`, `gce_sd_config`, `azure_sd_config`, `consul_sd_config`, `nomad_sd_config`, `http_sd_config`, `file_sd_config`:
  https://prometheus.io/docs/prometheus/latest/configuration/configuration/
- Relabeling (`relabel_configs` / `metric_relabel_configs`):
  https://prometheus.io/docs/prometheus/latest/configuration/configuration/#relabel_config
- Prometheus `/service-discovery` endpoint — qué muestra:
  https://prometheus.io/docs/prometheus/latest/management_api/

## Kubernetes

- Kubernetes RBAC — ClusterRole y ClusterRoleBinding:
  https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- kind quickstart:
  https://kind.sigs.k8s.io/docs/user/quick-start/

## Patrón "annotation-based scraping"

- Prometheus Operator — PodMonitor / ServiceMonitor (lo que automatiza este módulo):
  https://prometheus-operator.dev/docs/user-guides/getting-started/
- kube-prometheus-stack chart:
  https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

## Lecturas de refuerzo

- "Life of a Label" (Robust Perception):
  https://www.robustperception.io/life-of-a-label/
- Julius Volz — "Relabel to the Rescue":
  https://promlabs.com/blog/2021/04/28/how-relabeling-in-prometheus-works/
- SRE Workbook — Monitoring:
  https://sre.google/workbook/monitoring/

## Herramientas

- `promtool check config` — valida sintaxis de `prometheus.yml` offline.
- `promtool check service-discovery` — ejecuta un SD y devuelve los targets resueltos:
  https://prometheus.io/docs/prometheus/latest/command-line/promtool/
