# REFERENCE — gcp-08-02-cost-trim-logging

> Una referencia razonada. No es la única respuesta correcta.

## Archivos

- [`exclusion-filter.json`](./exclusion-filter.json) — 4 exclusions con salvaguarda NOT cloudaudit.
- [`sink.json`](./sink.json) — org-wide sink a BigQuery con tablas particionadas.
- [`LOG-RETENTION-ADR.md`](./LOG-RETENTION-ADR.md) — retention por bucket + 2 alternativas descartadas.
- [`README-INTENT.md`](./README-INTENT.md) — justificación operativa.

## Decisiones clave

| Decisión | Qué elegimos | Por qué |
|----------|--------------|---------|
| `_Default` retention | 14 días | Cubre análisis post-incidente; audit va al sink. |
| `_Required` | 400 d, gratis, no se toca | Es lo que lo hace útil estructuralmente. |
| Sink | Org-wide a BigQuery, partitioned | Un solo lugar para auditoría; retention barato. |
| Data Access | Solo Secret Manager + Cloud SQL | Selectivo = sostenible. |
| Salvaguarda NOT cloudaudit | En cada exclusion | Defensa contra filtros mal escritos. |

## Qué el validador NO comprueba

- Que tus patrones de exclusion matcheen *realmente* lo que tu tráfico produce.
- Que tu reducción del 65% se materialice (depende del tráfico real).
- Que el `writerIdentity` sea correcto en Fase 4 (lo asigna el servicio al crear el sink).

## Errores comunes

1. **Exclusion sin `NOT logName:"cloudaudit.googleapis.com"`**: si tu filter matcheó accidentalmente un log de audit, lo pierdes y violas compliance.
2. **Sink a BigQuery sin `usePartitionedTables=true`**: una sola tabla gigante, queries carísimas y expiration imposible por fecha.
3. **Retention `_Default` subida a 400d en vez de usar sink**: pricing malo. El bucket a largo plazo es más caro que BigQuery storage.
4. **Data Access activo "para todos los servicios"**: factura imprevista. Activar siempre selectivamente.
5. **Olvidar `includeChildren=true`** en el sink org-wide: solo captura logs del project donde está el sink, no del resto de la org.

## Terraform (walkthrough — no es parte del entregable)

```hcl
resource "google_logging_project_bucket_config" "default" {
  project        = var.project_id
  location       = "global"
  retention_days = 14
  bucket_id      = "_Default"
}

resource "google_logging_organization_sink" "audit_bq" {
  name             = "audit-logs-to-bq"
  org_id           = var.org_id
  destination      = "bigquery.googleapis.com/projects/${var.log_sink_project}/datasets/audit_logs"
  filter           = "logName:\"cloudaudit.googleapis.com\""
  include_children = true

  bigquery_options {
    use_partitioned_tables = true
  }
}

resource "google_logging_project_exclusion" "drop_health" {
  project     = var.project_id
  name        = "drop-health-probes"
  description = "GKE/Cloud Run readiness, liveness and healthz probes"
  filter      = <<EOT
    (httpRequest.requestUrl=~"/healthz|/readyz|/livez"
      OR textPayload=~"readiness probe|liveness probe")
    AND NOT logName:"cloudaudit.googleapis.com"
  EOT
}
```
