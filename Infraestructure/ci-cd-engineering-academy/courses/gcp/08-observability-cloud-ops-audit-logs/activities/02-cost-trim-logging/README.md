# Actividad 02 — Cost-trim de Cloud Logging + sink de audit a BigQuery

## 1. Identificación

- **ID:** `gcp-08-02-cost-trim-logging`
- **Tecnología:** `gcp`
- **Módulo:** `gcp-08-observability-cloud-ops-audit-logs`
- **Dificultad:** advanced
- **Duración estimada:** 60–80 min
- **Tipo:** independent

## 2. Contexto

La startup lleva 3 meses en GCP y la factura de **Cloud Logging** ha pasado de 10 USD/mes a 180 USD/mes. Investigación mínima en Log Analytics muestra:

- 55% del volumen son **health checks** de GKE y Cloud Run (`readiness`, `liveness`, `/healthz`).
- 20% son **debug logs** olvidados en un servicio tras un incidente (`log_level=DEBUG`).
- 10% son logs de **VPC Flow Logs** sin filtrar.
- 15% restante es "application logs útiles".

Simultáneamente, **Compliance** pide:

- Admin Activity logs **conservados 400 días** (ya lo son por `_Required`).
- Audit logs exportados a BigQuery para **queries SQL** y correlación.
- Data Access logs **activados sólo en Secret Manager y Cloud SQL** (no en BigQuery ni GCS por costo).

Tu encargo: diseñar la **retención por bucket**, los **exclusion filters** y el **sink de audit a BigQuery**, y documentarlo en un ADR corto. **No** hay project real. Placeholders obligatorios.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Escribir un `exclusion-filter.json` razonable para recortar health checks y debug sin romper auditoría.
- Escribir un `sink.json` que exporte audit logs a BigQuery con particionamiento.
- Decidir retención por bucket (`_Required`, `_Default`, `audit-long`) con justificación.
- Argumentar por qué Data Access logs no se activan en todos los servicios.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (en particular §3 Cloud Logging, §7 Audit Logs, §9 FinOps de logs).
- Haber recorrido `../../examples/02-log-analytics-walkthrough/` y `../../examples/03-audit-log-sink-to-bigquery/`.
- Herramientas: `bash`, `jq`, editor Markdown.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/gcp-08-cost
cd /tmp/gcp-08-cost
```

### 5.2 Escribe `exclusion-filter.json`

Un JSON con un array `exclusions` donde cada entrada tiene:

- `name`: identificador legible.
- `description`: una línea.
- `filter`: filtro de Cloud Logging que seleccione los logs a **excluir**.
- `disabled`: boolean (debe ser `false`).

El array debe contener **al menos 3 exclusions** cubriendo:

1. Health checks / probes.
2. Debug logs noisy (`severity<INFO` o `severity=DEBUG`).
3. VPC Flow Logs filtrables (p. ej. tráfico interno de health).

**Importante**: el filtro de exclusión **no debe matchear** logs con `logName:"cloudaudit.googleapis.com"` (romperías auditoría).

### 5.3 Escribe `sink.json`

Un JSON con:

- `name`: p. ej. `audit-logs-to-bq`.
- `destination`: `bigquery.googleapis.com/projects/LOG_SINK_PROJECT/datasets/audit_logs`.
- `filter`: `logName:"cloudaudit.googleapis.com"`.
- `includeChildren`: `true` (sink org-wide).
- `bigqueryOptions.usePartitionedTables`: `true`.
- `writerIdentity`: puede ser placeholder (p. ej. `"serviceAccount:p000000000000-000000@gcp-sa-logging.iam.gserviceaccount.com"`).

### 5.4 Escribe `LOG-RETENTION-ADR.md`

Secciones obligatorias:

1. `# ADR` ... (encabezado).
2. `## Estado` (o `Status`).
3. `## Contexto` (o `Context`).
4. `## Decisión` (o `Decision`) — tabla de buckets con retención justificada.
5. `## Consecuencias` (o `Consequences`).
6. `## Alternativas` (o `Alternatives`) — al menos 2.

Debe mencionar: `_Required`, `_Default`, `BigQuery`, `exclusion`, `400 d[ií]as`, `Data Access`, `Admin Activity`, `Secret Manager`.

### 5.5 Escribe `README-INTENT.md`

Secciones:

- `## exclusion-filter` — por qué cada filtro, qué impacto en factura esperado, por qué no toca `cloudaudit.googleapis.com`.
- `## sink` — por qué org-wide, por qué partitioned tables, por qué dataset separado.
- `## retention` — resumen de la decisión del ADR.

Debe mencionar: `health`, `DEBUG`, `audit`, `BigQuery`, `cloudaudit`.

### 5.6 Entregables

```
/tmp/gcp-08-cost/exclusion-filter.json
/tmp/gcp-08-cost/sink.json
/tmp/gcp-08-cost/LOG-RETENTION-ADR.md
/tmp/gcp-08-cost/README-INTENT.md
```

## 6. Resultado esperado

- Los 4 archivos existen y pasan el validador estructural (`0 issue(s)`).
- Sin project IDs reales (usa `PROJECT_ID`, `LOG_SINK_PROJECT`).
- Las exclusions no rompen auditoría.

## 7. Criterios de aceptación

- **Funcionalidad**: validador en verde.
- **Calidad**: cada exclusion justificada en `README-INTENT.md`.
- **Reproducibilidad**: los JSON son aplicables en Fase 4 tras sustituir placeholders.
- **Mantenibilidad**: Markdown válido, JSON pretty-printed.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gcp-08-cost
```

## 9. Preguntas de reflexión

1. Si tu exclusion también matcheara `cloudaudit.googleapis.com`, ¿qué dejaría de verse en el bucket? ¿Y en el sink a BigQuery?
2. ¿Por qué el ADR fija retención por bucket y no "a todos los logs"?
3. ¿Qué pasa el día que un auditor pide "muéstrame todos los `SetIamPolicy` del último año"? ¿Lo cubres con `_Required` o necesitas el sink a BigQuery?
4. Si Data Access logs se activan en Cloud SQL, ¿cómo evitas que inunden `_Default`? Hay 2 opciones; nómbralas.
5. ¿Cómo detectas que un nuevo servicio empezó a logear como un loco antes de que llegue la factura?

## 10. Extensiones

- Añadir `log-based-metric.json` que cuente ingesta por `resource.type` (meta-métrica para FinOps).
- Añadir una `budget-alert.json` sobre el billing export en BigQuery.
- Modelar un bucket custom `security-7y` con retention 2555 días para forensics.

## 11. Limpieza

```bash
rm -rf /tmp/gcp-08-cost
```
