# Recursos — aws-12

Referencias oficiales. Verificar vigencia (los precios y features de AWS cambian).

## CloudWatch Logs

- Guía general: `https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html`
- Metric filters: `https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitoringLogData.html`
- Logs Insights (queries): `https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html`
- Precios CloudWatch: `https://aws.amazon.com/cloudwatch/pricing/`

## CloudWatch Metrics y Alarms

- Custom metrics: `https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/publishingMetrics.html`
- Embedded Metric Format (EMF): `https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Embedded_Metric_Format.html`
- Librería `aws-embedded-metrics-python`: `https://github.com/awslabs/aws-embedded-metrics-python`
- Alarms (static, anomaly, composite): `https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html`
- Composite alarms: `https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Create_Composite_Alarm_How_To.html`

## Container Insights (ECS/EKS)

- Container Insights: `https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html`

## X-Ray

- X-Ray concepts: `https://docs.aws.amazon.com/xray/latest/devguide/aws-xray.html`
- Sampling rules: `https://docs.aws.amazon.com/xray/latest/devguide/xray-console-sampling.html`

## ADOT (AWS Distro for OpenTelemetry)

- Portal ADOT: `https://aws-otel.github.io/`
- Receivers/exporters AWS en Collector contrib: `https://github.com/aws-observability/aws-otel-collector`
- Exporter `awsxray`: `https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/awsxrayexporter`
- Exporter `awsemf`: `https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/awsemfexporter`
- Exporter `awscloudwatchlogs`: `https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/awscloudwatchlogsexporter`

## CloudTrail

- CloudTrail guía: `https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-user-guide.html`
- Organization trail: `https://docs.aws.amazon.com/awscloudtrail/latest/userguide/creating-trail-organization.html`
- Data events: `https://docs.aws.amazon.com/awscloudtrail/latest/userguide/logging-data-events-with-cloudtrail.html`
- CloudTrail Insights: `https://docs.aws.amazon.com/awscloudtrail/latest/userguide/logging-insights-events-with-cloudtrail.html`
- Precios CloudTrail: `https://aws.amazon.com/cloudtrail/pricing/`

## CloudWatch Agent vs ADOT

- CloudWatch Agent: `https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html`
- Comparativa (post AWS Observability): `https://aws.amazon.com/blogs/opensource/`

## LocalStack (para los smoke tests opcionales)

- CloudWatch Logs en LocalStack (free tier): `https://docs.localstack.cloud/user-guide/aws/cloudwatch/`
- X-Ray en LocalStack (requiere Pro): `https://docs.localstack.cloud/user-guide/aws/xray/`
- CloudTrail en LocalStack (Pro): `https://docs.localstack.cloud/user-guide/aws/cloudtrail/`

## Para completar el panorama OSS (contexto del programa)

- Prometheus Remote Write: `https://prometheus.io/docs/concepts/remote_write_spec/`
- Grafana Tempo: `https://grafana.com/docs/tempo/latest/`
- OTel Collector contrib: `https://github.com/open-telemetry/opentelemetry-collector-contrib`

## Checklist de verificación en Fase 4

- Precio actual de ingestión CloudWatch Logs (USD/GB) por región.
- Última versión de ADOT Collector y receivers/exporters que incluye.
- Estado de **CloudWatch Application Signals** (observabilidad nueva basada en OTel) — si estabiliza, puede sustituir X-Ray a futuro.
- Soporte de **CloudTrail Lake** como alternativa a buckets S3 para auditoría consultable con SQL.
