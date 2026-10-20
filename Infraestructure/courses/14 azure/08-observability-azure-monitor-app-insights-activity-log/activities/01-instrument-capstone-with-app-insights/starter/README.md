# Starter — az-08-01-instrument-capstone-with-app-insights

Esta actividad es **independiente**: produces 4 archivos técnicos (walkthrough, 2 JSON, 1 KQL) + 1 Markdown de intent.

## Pasos

1. Lee `../README.md` completo y recorre los tres `examples/` del módulo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/az-08-01
   cd /tmp/az-08-01
   ```
3. Crea los 5 archivos (nombres exactos):
   - `otel-walkthrough.md`
   - `log-analytics-workspace.json`
   - `app-insights-alert.json`
   - `kql-queries.kql`
   - `README-INTENT.md`
4. Verifica que los JSON son válidos:
   ```bash
   for f in *.json; do echo "--- $f"; jq empty "$f" && echo OK; done
   ```
5. Valida la estructura completa:
   ```bash
   bash <ruta-repo>/courses/azure/08-observability-azure-monitor-app-insights-activity-log/activities/01-instrument-capstone-with-app-insights/tests/validate.sh /tmp/az-08-01
   ```
6. Compara tus archivos con `../solution/REFERENCE.md` y los adjuntos para autoevaluarte.

> **Importante:** el validador comprueba estructura, no semántica. No uses GUIDs reales de tenant/suscripción (usa `REDACTED-TENANT-ID`, `REDACTED-SUB-ID`, `REDACTED-WORKSPACE-ID`).

## Esqueletos útiles

### `log-analytics-workspace.json`

```json
{
  "type": "Microsoft.OperationalInsights/workspaces",
  "apiVersion": "2022-10-01",
  "name": "la-shared-prod",
  "location": "westeurope",
  "properties": {
    "sku": { "name": "PerGB2018" },
    "retentionInDays": 30,
    "publicNetworkAccessForIngestion": "Enabled",
    "publicNetworkAccessForQuery": "Enabled"
  }
}
```

### `app-insights-alert.json`

```json
{
  "type": "Microsoft.Insights/scheduledQueryRules",
  "apiVersion": "2023-03-15-preview",
  "name": "alert-checkout-5xx",
  "location": "westeurope",
  "properties": {
    "severity": 2,
    "enabled": true,
    "scopes": [
      "/subscriptions/REDACTED-SUB-ID/resourceGroups/rg-platform-observability/providers/Microsoft.OperationalInsights/workspaces/la-shared-prod"
    ],
    "evaluationFrequency": "PT5M",
    "windowSize": "PT15M",
    "criteria": {
      "allOf": [
        {
          "query": "AppRequests | where TimeGenerated > ago(15m) | where ResultCode startswith \"5\" | summarize failed = count()",
          "timeAggregation": "Count",
          "operator": "GreaterThan",
          "threshold": 10,
          "failingPeriods": { "numberOfEvaluationPeriods": 1, "minFailingPeriodsToAlert": 1 }
        }
      ]
    },
    "actions": { "actionGroups": [] }
  }
}
```

### `kql-queries.kql`

```kusto
// Query 1: tasa de errores (5xx) por minuto
AppRequests
| where TimeGenerated > ago(1h)
| summarize total = count(), failed = countif(ResultCode startswith "5")
        by bin(TimeGenerated, 1m)
| extend error_rate = round(100.0 * failed / total, 2)

//---
// Query 2: p95 y p99 de latencia por endpoint
AppRequests
| where TimeGenerated > ago(1h)
| summarize p95 = percentile(DurationMs, 95),
            p99 = percentile(DurationMs, 99)
        by Name, bin(TimeGenerated, 1m)

//---
// Query 3: correlacion excepcion -> request padre
AppExceptions
| where TimeGenerated > ago(15m)
| join kind=inner (AppRequests) on OperationId
| project TimeGenerated, ExceptionType, Url, ResultCode, OperationId
```

### `README-INTENT.md`

```markdown
# README-INTENT — az-08-01

## otel-walkthrough
<por que elegimos azure-monitor-opentelemetry, no SDK legacy>

## log-analytics-workspace
<sku, retention, por que publicNetworkAccess Enabled en dev>

## app-insights-alert
<umbral, ventana, severidad, por que scheduledQueryRules y no metricAlerts>

## kql-queries
<para que sirve cada query, con quien se compartira>

<Mencion de OpenTelemetry, Application Insights, Log Analytics, KQL>
```
