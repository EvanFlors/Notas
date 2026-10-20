# Starter — gcp-08-01-slo-and-alerting-policy-json

Actividad **independiente**: no hay código que ejecutar; produces 4 documentos.

## Pasos

1. Lee `../README.md` y recorre `../../examples/01-otel-to-cloud-trace-adot/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gcp-08-slo
   cd /tmp/gcp-08-slo
   ```
3. Crea los 4 entregables:
   - `alerting-policy.json`
   - `logs-based-metric.json`
   - `SLO-ADR.md`
   - `README-INTENT.md`
4. Valida:
   ```bash
   bash <ruta-repo>/courses/gcp/08-observability-cloud-ops-audit-logs/activities/01-slo-and-alerting-policy-json/tests/validate.sh /tmp/gcp-08-slo
   ```
5. Compara con `../solution/REFERENCE.md`.

## Plantillas (opcional)

### `alerting-policy.json` (esqueleto)

```json
{
  "displayName": "checkout-api — <condicion>",
  "combiner": "OR",
  "conditions": [
    {
      "displayName": "<descripcion>",
      "conditionThreshold": {
        "filter": "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": 0.01,
        "duration": "300s",
        "aggregations": [
          {"alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_RATE"}
        ]
      }
    }
  ],
  "notificationChannels": ["projects/PROJECT_ID/notificationChannels/CHANNEL_ID"],
  "documentation": {
    "content": "Runbook: ... | Dashboard: ... | Owner: team-checkout",
    "mimeType": "text/markdown"
  },
  "alertStrategy": {"autoClose": "1800s"}
}
```

### `logs-based-metric.json` (esqueleto)

```json
{
  "name": "payment_declined_count",
  "description": "Count of payment_declined events emitted by checkout-api",
  "filter": "resource.type=\"cloud_run_revision\" AND jsonPayload.event=\"payment_declined\"",
  "metricDescriptor": {
    "metricKind": "DELTA",
    "valueType": "INT64",
    "unit": "1",
    "labels": [
      {"key": "reason", "valueType": "STRING", "description": "Decline reason code"}
    ]
  },
  "labelExtractors": {
    "reason": "EXTRACT(jsonPayload.reason)"
  }
}
```

### `SLO-ADR.md` (esqueleto)

```markdown
# ADR 001 — SLO de disponibilidad para checkout-api

## Estado
Propuesto

## Contexto
<por qué: SLA interno 99.9%, Cloud Run, criticidad de la ruta de pago>

## Decisión
### SLI
### SLO (goal + rolling period)
### Burn rate alerts
### Logs-based metric complementaria

## Consecuencias
### Positivas
### Negativas

## Alternativas descartadas
### Alt A: alertar por threshold de 5xx sin SLO
### Alt B: SLO con rolling period 7 dias
```

### `README-INTENT.md` (esqueleto)

```markdown
# Intent — SLO + alerting + log-based metric para checkout-api

## alerting-policy
...

## logs-based-metric
...

## SLO
...

(Mencionar: burn rate, notificationChannels, documentation.)
```
