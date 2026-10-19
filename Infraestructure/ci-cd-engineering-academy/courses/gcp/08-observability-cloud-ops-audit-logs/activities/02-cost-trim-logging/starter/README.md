# Starter — gcp-08-02-cost-trim-logging

Actividad **independiente**. Entregas 4 archivos.

## Pasos

1. Lee `../README.md` y los dos examples relevantes (`02-log-analytics-walkthrough`, `03-audit-log-sink-to-bigquery`).
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gcp-08-cost
   cd /tmp/gcp-08-cost
   ```
3. Crea:
   - `exclusion-filter.json`
   - `sink.json`
   - `LOG-RETENTION-ADR.md`
   - `README-INTENT.md`
4. Valida:
   ```bash
   bash <ruta-repo>/courses/gcp/08-observability-cloud-ops-audit-logs/activities/02-cost-trim-logging/tests/validate.sh /tmp/gcp-08-cost
   ```
5. Compara con `../solution/REFERENCE.md`.

## Plantillas (opcional)

### `exclusion-filter.json`

```json
{
  "bucket": "projects/PROJECT_ID/locations/global/buckets/_Default",
  "exclusions": [
    {
      "name": "drop-health-probes",
      "description": "GKE/Cloud Run readiness and liveness probes",
      "filter": "(httpRequest.requestUrl=~\"/healthz|/readyz|/livez\" OR textPayload=~\"readiness|liveness probe\") AND NOT logName:\"cloudaudit.googleapis.com\"",
      "disabled": false
    }
  ]
}
```

### `sink.json`

```json
{
  "name": "audit-logs-to-bq",
  "destination": "bigquery.googleapis.com/projects/LOG_SINK_PROJECT/datasets/audit_logs",
  "filter": "logName:\"cloudaudit.googleapis.com\"",
  "includeChildren": true,
  "bigqueryOptions": {"usePartitionedTables": true},
  "writerIdentity": "serviceAccount:p000000000000-000000@gcp-sa-logging.iam.gserviceaccount.com",
  "disabled": false
}
```

### `LOG-RETENTION-ADR.md` (esqueleto)

```markdown
# ADR 002 — Retencion y exclusiones de Cloud Logging

## Estado
Propuesto

## Contexto
<factura de 180 USD/mes; health checks 55%; Compliance pide 400 dias>

## Decisión
### Retención por bucket
| Bucket | Retention | Justificación |
### Exclusion filters en _Default
### Sink org-wide a BigQuery
### Data Access logs activados sólo en Secret Manager y Cloud SQL

## Consecuencias
### Positivas
### Negativas

## Alternativas descartadas
### Alt A: desactivar _Default por completo
### Alt B: subir retention _Default a 400 dias
```

### `README-INTENT.md` (esqueleto)

```markdown
# Intent — cost-trim de Cloud Logging

## exclusion-filter
...

## sink
...

## retention
...

(Mencionar: health, DEBUG, audit, BigQuery, cloudaudit.)
```
