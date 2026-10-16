# Recursos — obs-09

## Documentacion oficial
- Prometheus — Alerting rules: https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/
- Prometheus — Unit testing for rules (`promtool test rules`): https://prometheus.io/docs/prometheus/latest/configuration/unit_testing_rules/
- Prometheus — `promtool`: https://prometheus.io/docs/prometheus/latest/command-line/promtool/
- Alertmanager — Configuration: https://prometheus.io/docs/alerting/latest/configuration/
- Alertmanager — `amtool`: https://github.com/prometheus/alertmanager#amtool
- Alertmanager — Inhibition: https://prometheus.io/docs/alerting/latest/configuration/#inhibit_rule
- Alertmanager — HA / clustering: https://github.com/prometheus/alertmanager#high-availability

## Diseno de alertas (lectura obligatoria)
- Google SRE Book — "Monitoring Distributed Systems": https://sre.google/sre-book/monitoring-distributed-systems/
- Google SRE Book — "Practical Alerting": https://sre.google/sre-book/practical-alerting/
- Google SRE Workbook — "Alerting on SLOs" (multi-window, multi-burn-rate): https://sre.google/workbook/alerting-on-slos/
- "My Philosophy on Alerting" (Rob Ewaschuk, Google): https://docs.google.com/document/d/199PqyG3UsyXlwieHaqbGiWVa8eMWi8zzAn0YfcApr8Q/edit

## Patrones y plantillas
- Awesome Prometheus Alerts (coleccion mantenida): https://samber.github.io/awesome-prometheus-alerts/
- kubernetes-mixin (alerts + dashboards oficiales para K8s): https://github.com/kubernetes-monitoring/kubernetes-mixin
- Prometheus Operator — `PrometheusRule` CRD: https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.PrometheusRule
- Prometheus Operator — `AlertmanagerConfig` CRD: https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1alpha1.AlertmanagerConfig

## Receivers
- Slack webhook format: https://api.slack.com/messaging/webhooks
- PagerDuty Events API v2: https://developer.pagerduty.com/docs/events-api-v2/overview/
- Microsoft Teams incoming webhook: https://learn.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/
- Opsgenie integration: https://support.atlassian.com/opsgenie/docs/integrate-opsgenie-with-prometheus/

## Herramientas complementarias
- `pint` (Cloudflare) — linter para reglas Prometheus: https://cloudflare.github.io/pint/
- `promlens` — explorador de PromQL: https://promlens.com/
- `alertmanager-webhook-logger` — util para probar webhooks localmente: https://github.com/tomtom-international/alertmanager-webhook-logger

## Lecturas recomendadas en el programa
- Modulo siguiente: `obs-10-promql-advanced-recording-rules-cardinality` (recording rules para alertas).
- Modulo relacionado: `obs-14-slo-sli-and-burn-rate-alerts` (profundiza en multi-window burn-rate).
