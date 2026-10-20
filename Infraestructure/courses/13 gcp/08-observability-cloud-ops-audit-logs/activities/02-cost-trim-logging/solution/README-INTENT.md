# Intent — cost-trim de Cloud Logging

Explica qué hace cada archivo y por qué. Lee junto con `LOG-RETENTION-ADR.md`.

## exclusion-filter

Recorta las 3 fuentes identificadas como ruidosas (health probes, DEBUG en prod, VPC Flow intra-VPC) **sin tocar `cloudaudit.googleapis.com`**. Cada filtro lleva una salvaguarda explícita `AND NOT logName:"cloudaudit.googleapis.com"` — un exclusion filter mal escrito podría borrar silenciosamente evidencia de auditoría, lo que rompería compliance y dejaría al equipo de seguridad sin señal. La salvaguarda es defensiva: hace al JSON robusto a cambios futuros.

- **drop-health-probes**: patrón de URL + payload. Esperado: ~55% del ingesta actual.
- **drop-debug-in-prod**: `severity<INFO` en `environment=prod`. Esperado: ~15% adicional (los DEBUG olvidados del incidente).
- **drop-vpc-flow-internal**: VPC Flow Logs intra-VPC. ~8% adicional.
- **drop-successful-gcs-reads**: 2xx GCS en bucket público (ruido puro).

Totales esperados: ~65% reducción de ingesta en `_Default`.

## sink

Un único sink **org-wide** hacia BigQuery (`LOG_SINK_PROJECT.audit_logs`):

- **`includeChildren=true`**: captura todos los projects bajo la org. Un sink por project sería N veces el trabajo administrativo y rompe el principio de "una sola vista central".
- **`usePartitionedTables=true`**: cada día = una partición. Permite expiration automático a 400 días con una sola config a nivel dataset.
- **Filter `logName:"cloudaudit.googleapis.com"`**: solo audit — Admin Activity, Data Access, System Event, Policy Denied. **No** copiamos application logs al sink (serían demasiado volumen).
- **Dataset separado (`audit_logs`)**: ACL independiente, retention independiente, cost center separado para Finance.
- **writerIdentity**: placeholder; en Fase 4 el sink se crea y el SA generado recibe `roles/bigquery.dataEditor` en el dataset.

## retention

Resumen de la decisión del ADR:

- `_Required` → **400 días**, inmutable, gratis. Admin Activity + System Event.
- `_Default` → **14 días** (reducido desde 30). Application + debug.
- Sink BigQuery `audit_logs` → **400 días** (particionado por día). Audit queryable con SQL.

Decisión por bucket, no "para todos los logs". Es el pattern que escala: diferentes datos tienen diferentes contratos.

## Data Access logs

Activados **sólo** en `Secret Manager` (DATA_READ + DATA_WRITE) y `Cloud SQL` (DATA_WRITE + ADMIN_READ). Explícitamente NO en GCS ni BigQuery (volumen potencial reventaría el presupuesto). Esta decisión se revisa trimestralmente.

## Qué queda fuera

- Dashboard de ingesta por `resource.type` (fuera del scope JSON de esta actividad; se materializa en Fase 4).
- Billing export a BigQuery para dashboards FinOps (`gcp-10`).
- SIEM externo (Splunk/Datadog) vía Pub/Sub sink (no hay SIEM aún en la org).
