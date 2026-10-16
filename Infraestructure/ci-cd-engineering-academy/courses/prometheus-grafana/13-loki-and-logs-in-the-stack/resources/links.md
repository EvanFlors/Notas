# Recursos — obs-13 Loki y logs

## Oficial

- Loki docs: https://grafana.com/docs/loki/latest/
- LogQL reference: https://grafana.com/docs/loki/latest/query/
- Loki best practices (labels): https://grafana.com/docs/loki/latest/get-started/labels/
- Grafana Alloy docs: https://grafana.com/docs/alloy/latest/
- Alloy components (`loki.source.*`, `loki.write`): https://grafana.com/docs/alloy/latest/reference/components/
- Promtail deprecation / migration to Alloy: https://grafana.com/docs/alloy/latest/tutorials/migrate-from-promtail/
- OpenTelemetry Collector: https://opentelemetry.io/docs/collector/
- Vector docs: https://vector.dev/docs/
- Fluent Bit docs: https://docs.fluentbit.io/

## Patterns & deep dives

- "How Loki works" (Grafana Labs blog series).
- Loki storage (TSDB index, chunks): https://grafana.com/docs/loki/latest/operations/storage/
- Loki recording rules: https://grafana.com/docs/loki/latest/alert/#recording-rules
- Grafana data links & derived fields: https://grafana.com/docs/grafana/latest/panels-visualizations/configure-data-links/

## Prácticas de equipo

- Google SRE Workbook — capítulos sobre monitoring & observability (encaje de logs en el stack).
- Charity Majors — "Observability: a Manifesto" (contexto filosófico de logs vs eventos ricos).
- Logs as events (structured logging): justificación de loguear JSON desde el día 1.

## Costos

- Grafana Cloud pricing (modelo "GB ingested per month") — referencia mental de self-hosted.
- S3 lifecycle policies (archivar chunks viejos a Glacier).
