# Recursos — gcp-08

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso para asegurar vigencia (consolas, nombres y pricing cambian).

## Oficiales (GCP)

- **Cloud Logging documentation**: `https://cloud.google.com/logging/docs`
- **Cloud Monitoring documentation**: `https://cloud.google.com/monitoring/docs`
- **Cloud Trace documentation**: `https://cloud.google.com/trace/docs`
- **Cloud Profiler**: `https://cloud.google.com/profiler/docs`
- **Audit Logs overview**: `https://cloud.google.com/logging/docs/audit`
- **Data Access audit logs — enable**: `https://cloud.google.com/logging/docs/audit/configure-data-access`
- **Log sinks (routing)**: `https://cloud.google.com/logging/docs/export`
- **Log-based metrics**: `https://cloud.google.com/logging/docs/logs-based-metrics`
- **Log Analytics (SQL on log buckets)**: `https://cloud.google.com/logging/docs/log-analytics`
- **Service monitoring / SLOs API**: `https://cloud.google.com/monitoring/service-monitoring`
- **Alerting policies API reference**: `https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.alertPolicies`

## OpenTelemetry y Collector

- **OpenTelemetry docs**: `https://opentelemetry.io/docs/`
- **OTel Collector contrib**: `https://github.com/open-telemetry/opentelemetry-collector-contrib`
- **AWS Distro for OpenTelemetry (ADOT)**: `https://aws-otel.github.io/`
- **Collector exporter `googlecloud`**: `https://github.com/GoogleCloudPlatform/opentelemetry-operations-collector`

## Pricing (confirmar en Fase 4)

- **Cloud Logging pricing**: `https://cloud.google.com/stackdriver/pricing#logging-costs`
- **Cloud Monitoring pricing**: `https://cloud.google.com/stackdriver/pricing#monitoring-costs`
- **Cloud Trace pricing**: `https://cloud.google.com/stackdriver/pricing#trace-costs`
- **BigQuery storage + query pricing**: `https://cloud.google.com/bigquery/pricing`

## Terraform (referencia, no laboratorio en este módulo)

- **`terraform-google-modules/log-export/google`** (sinks a BigQuery/GCS/Pub/Sub): `https://registry.terraform.io/modules/terraform-google-modules/log-export/google/latest`
- **Google Cloud Monitoring Terraform resources**: `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy`

## Comparativa AWS (contexto)

- **CloudWatch Logs pricing**: `https://aws.amazon.com/cloudwatch/pricing/`
- **CloudTrail pricing**: `https://aws.amazon.com/cloudtrail/pricing/`
- Charla recomendada: "What's new in Google Cloud observability" (Google Cloud Next, buscar edición más reciente).
- Charla recomendada: "Reliable alerting with SLOs" (SREcon, varias ediciones).

## Checklist de verificación requerida en Fase 4

- Nombres vigentes de los servicios (Cloud Logging / Monitoring / Trace / Profiler) — no debería haber cambiado desde el rename de Stackdriver, pero validar.
- Vigencia de Log Analytics (fue GA relativamente reciente; validar features y disponibilidad regional).
- Soporte actual del exporter `googlecloud` en Collector contrib y en ADOT (version matrix).
- Precios actualizados de ingesta en `_Default` y de métricas custom (free tier puede moverse).
- Estado de los **SLO services** auto-detectados (soportan nuevos tipos de recurso con el tiempo).
- Vigencia de `--use-partitioned-tables` como default o deprecación de alternativas.
