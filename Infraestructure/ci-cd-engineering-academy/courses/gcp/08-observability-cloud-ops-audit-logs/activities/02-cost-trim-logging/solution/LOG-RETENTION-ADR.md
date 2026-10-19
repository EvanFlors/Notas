# ADR 002 — Retención y exclusiones de Cloud Logging

## Estado

Propuesto (Fase 3). Materializar con Terraform en Fase 4 (`google_logging_project_bucket_config`, `google_logging_project_exclusion`, `google_logging_organization_sink`).

## Contexto

La factura de Cloud Logging pasó de ~10 a ~180 USD/mes en 3 meses. Breakdown (Log Analytics):

- 55% health probes (GKE + Cloud Run).
- 20% debug logs olvidados en un service tras un incidente.
- 10% VPC Flow Logs sin filtrar.
- 15% application logs útiles.

Simultáneamente, Compliance exige:

- Admin Activity logs conservados **400 días** (ya es default por `_Required`).
- Audit logs exportados a BigQuery para análisis SQL y correlación con otros eventos.
- Data Access logs activados **sólo** en `Secret Manager` y `Cloud SQL` (no en BigQuery ni GCS por costo).

Queremos recortar la factura ≥50% sin romper auditoría ni perder debugging útil.

## Decisión

### 1. Retención por bucket

| Bucket | Retention | Pricing | Justificación |
|--------|-----------|---------|---------------|
| `_Required` | **400 días** (fijo, inmutable) | Gratis | Admin Activity + System Event. No se toca. |
| `_Default` | **14 días** (reducido desde 30) | 50 GiB/mes gratis + per GiB | Debug y app logs. 14 días cubre análisis post-incidente típico. |
| `audit-long` (bucket custom) | **400 días** | per GiB | Opcional: espejo local de audit si no quisiéramos BigQuery sink. En nuestro caso NO lo creamos — usamos sink a BigQuery (más barato a 400d). |
| `security-7y` (bucket custom) | 2555 días | per GiB | **Fuera de alcance** de esta ADR; se evaluará si Compliance lo pide. |

### 2. Exclusion filters en `_Default`

Ver `exclusion-filter.json`. Cuatro exclusions:

1. `drop-health-probes` — regex sobre URLs `/healthz|/readyz|/livez` + patrones de probe en payload.
2. `drop-debug-in-prod` — `severity<INFO AND resource.labels.environment="prod"`.
3. `drop-vpc-flow-internal` — VPC Flow Logs intra-VPC.
4. `drop-successful-gcs-reads` — 2xx reads al bucket público de assets.

**Todas** llevan `AND NOT logName:"cloudaudit.googleapis.com"` como salvaguarda: una exclusion mal escrita no debe borrar audit.

Impacto esperado: ~65% reducción de ingesta en `_Default`.

### 3. Sink org-wide a BigQuery

Ver `sink.json`. Un único sink en el nivel organización:

- Filter: `logName:"cloudaudit.googleapis.com"` (todas las 4 categorías de audit).
- Destination: `bigquery.googleapis.com/projects/LOG_SINK_PROJECT/datasets/audit_logs`.
- `includeChildren=true` → captura todos los projects bajo la org.
- `usePartitionedTables=true` → una tabla particionada por día por categoría de audit log.
- Retention en BigQuery: 400 días vía `--default_partition_expiration=34560000` en el dataset (fuera del JSON del sink).

### 4. Data Access logs — activados selectivamente

Enabled:

- **Secret Manager**: `DATA_READ` + `DATA_WRITE`. Volumen bajo, criticidad alta.
- **Cloud SQL**: `DATA_WRITE` + `ADMIN_READ`. `DATA_READ` NO (podría ser muy voluminoso).

Disabled (default):

- **GCS**, **BigQuery**, resto — por costo y por bajo valor incremental dado el volumen.

### 5. FinOps: dashboard de ingesta

Dashboard en Cloud Monitoring sobre `logging.googleapis.com/billing/bytes_ingested` agrupado por `resource.type`. Alerta cuando ingesta diaria > 2× la media de 7 días. Fuera del JSON de esta ADR — se materializa en Fase 4 con otro `google_monitoring_dashboard`.

## Consecuencias

### Positivas

- Reducción esperada de factura `_Default` ~65%; proyección ~70 USD/mes en vez de 180.
- Audit queryable con SQL en BigQuery, retención 400d, analytics friendly.
- Compliance de 400d garantizada por `_Required` (gratis) + sink BigQuery.
- Debug logs no desaparecen — solo se reducen a 14 días y se filtra el ruido obvio.

### Negativas

- Si Data Access logs se activan accidentalmente en BigQuery o GCS, pueden reventar el presupuesto. Mitigación: alert sobre ingesta diaria.
- Debug a > 14 días requiere consultar el sink de BigQuery (sólo audit) o reconstruir desde snapshots. No es un trade-off cero.
- Mantener los exclusion filters requiere revisarlos cuando aparece un servicio nuevo. Mitigación: lint en Terraform PR + revisión trimestral.
- Equipos acostumbrados a "los logs están todos ahí para siempre" deben adaptar su mental model.

## Alternativas descartadas

### Alternativa A: desactivar `_Default` por completo (sink de todo a BigQuery)

- Pros: pricing BigQuery storage es más barato que log bucket a volumen alto.
- Contras: pierdes Logs Explorer y Log Analytics sobre logs recientes; cada query es BigQuery scan; UX peor para incident response. Rechazada hoy; se re-evalúa a >500 GiB/mes.

### Alternativa B: subir retention `_Default` a 400 días en vez del sink a BigQuery

- Pros: una sola fuente de verdad.
- Contras: pricing de log bucket a 400d es materialmente más caro que BigQuery storage. Y Logs Explorer sobre 400d es incómodo. Rechazada.

### Alternativa C: Pub/Sub sink hacia Splunk (SIEM externo) en vez de BigQuery

- Pros: real-time para equipo de seguridad; dashboards de SOC conocidos.
- Contras: no tenemos SIEM aún; coste de Splunk fuera de scope. Se mantiene para `gcp-10` o cuando llegue el requisito. Hoy, BigQuery cubre análisis + compliance.
