# Ejemplo 03 — Sink de Audit Logs a BigQuery

> Walkthrough. Lectura y análisis. Sin ejecución. Objetivo: ver cómo se exporta la auditoría (Admin Activity + Data Access opcional) a un dataset BigQuery para análisis a largo plazo.

## 1. Topología objetivo

```
┌───────────────────────────┐    ┌───────────────────────────┐    ┌─────────────────────┐
│  project: workload-prod   │    │  project: workload-dev    │    │   project: ...      │
│                           │    │                           │    │                     │
│  Admin Activity (always)  │    │  Admin Activity (always)  │    │  ...                │
│  Data Access (opt-in)     │    │  Data Access (off)        │    │                     │
└──────────────┬────────────┘    └──────────────┬────────────┘    └──────────┬──────────┘
               │                                 │                            │
               └──────── ORG-WIDE SINK ──────────┴────────────────────────────┘
                                 filter: logName:"cloudaudit.googleapis.com"
                                 destination: bigquery.googleapis.com/
                                   projects/LOG_SINK_PROJECT/
                                   datasets/audit_logs
                                 includeChildren: true
                                 ▼
                 ┌──────────────────────────────────────────┐
                 │  project: LOG_SINK_PROJECT               │
                 │  dataset: audit_logs                     │
                 │                                          │
                 │  cloudaudit_googleapis_com_activity_*    │  <- partitioned by day
                 │  cloudaudit_googleapis_com_data_access_* │
                 │  cloudaudit_googleapis_com_system_event_*│
                 │  cloudaudit_googleapis_com_policy_*      │
                 │                                          │
                 │  table expiration: 400 days (per policy) │
                 └──────────────────────────────────────────┘
```

`LOG_SINK_PROJECT` es placeholder; **no** es un project real.

## 2. Por qué un sink org-wide y no uno por project

- **Un solo lugar donde preguntar** "¿quién creó esto?". Si cada project tuviese su propio dataset, un auditor haría 20 queries y las uniría a mano.
- **Permisos simples**: solo el equipo de seguridad accede a `LOG_SINK_PROJECT`. Los equipos de workload no ven la auditoría de otros equipos (good — reducción de blast-radius de información).
- **Retención controlada centralizada**: una política de borrado (`table_expiration`) aplica a todas las tablas particionadas por día.

## 3. Config del sink (walkthrough)

```bash
# NO se ejecuta. Placeholders obvios.
gcloud logging sinks create audit-logs-to-bq \
  bigquery.googleapis.com/projects/LOG_SINK_PROJECT/datasets/audit_logs \
  --log-filter='logName:"cloudaudit.googleapis.com"' \
  --organization=ORG_ID \
  --include-children \
  --use-partitioned-tables
```

- `--include-children`: aplica a todos los projects/folders bajo la org.
- `--use-partitioned-tables`: cada tabla particionada por día (`_YYYYMMDD` sufijo). Barato de query, barato de expirar.
- El sink crea un **service account** `p<numeric-id>-xxxxxx@gcp-sa-logging.iam.gserviceaccount.com` que necesita `roles/bigquery.dataEditor` en el dataset destino.

## 4. Pricing mental model

| Fuente | ¿Factura? | Orden de magnitud |
|--------|-----------|-------------------|
| Admin Activity logs (origen) | **Gratis**. | — |
| Data Access logs (origen, si activados) | Precio de Cloud Logging. | GiB/día dependiente del tráfico. |
| Sink hacia BigQuery (transporte) | **Gratis** (el export en sí). | — |
| BigQuery **storage** del destino | Precio BigQuery storage. | Low (long-term pricing al mes 90). |
| BigQuery **queries** sobre el destino | Precio BigQuery on-demand. | Dependiente de los analistas. |

**Nota crítica**: lo barato es el transporte. Lo caro (si lo activas) es **Data Access logs en servicios con tráfico alto** (GCS, BigQuery `DATA_READ`). Esto se decide por servicio, no "para todo".

## 5. Retention de 400 días

Patrón canónico:

```sql
-- Walkthrough SQL. NO ejecutar.
-- Se corre como scheduled query diaria en LOG_SINK_PROJECT.

FOR table_name IN (
  SELECT table_name
  FROM `LOG_SINK_PROJECT.audit_logs.INFORMATION_SCHEMA.TABLES`
  WHERE table_name LIKE 'cloudaudit_googleapis_com_%'
    AND REGEXP_EXTRACT(table_name, r'_(\d{8})$') IS NOT NULL
    AND PARSE_DATE('%Y%m%d', REGEXP_EXTRACT(table_name, r'_(\d{8})$'))
        < DATE_SUB(CURRENT_DATE(), INTERVAL 400 DAY)
)
DO
  EXECUTE IMMEDIATE FORMAT('DROP TABLE `LOG_SINK_PROJECT.audit_logs.%s`', table_name);
END FOR;
```

(Lo recomendado en producción es usar la **table expiration** a nivel dataset: `bq update --default_partition_expiration=34560000 ...` — 400 días en segundos. Más simple que el script.)

## 6. Queries típicas sobre el dataset

### 6.1 IAM changes últimas 24h

```sql
SELECT
  timestamp,
  protoPayload.authenticationInfo.principalEmail AS who,
  protoPayload.methodName AS what,
  resource.labels.project_id AS project,
  protoPayload.resourceName AS target
FROM `LOG_SINK_PROJECT.audit_logs.cloudaudit_googleapis_com_activity_*`
WHERE
  _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', CURRENT_DATE())
  AND protoPayload.methodName IN (
    'google.iam.admin.v1.SetIamPolicy',
    'google.iam.admin.v1.CreateServiceAccount',
    'google.iam.admin.v1.CreateServiceAccountKey'
  )
ORDER BY timestamp DESC;
```

### 6.2 Service account key creations (señal de alarma)

```sql
SELECT
  timestamp,
  protoPayload.authenticationInfo.principalEmail AS who,
  protoPayload.resourceName AS sa_affected
FROM `LOG_SINK_PROJECT.audit_logs.cloudaudit_googleapis_com_activity_*`
WHERE
  _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
                   AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
  AND protoPayload.methodName = 'google.iam.admin.v1.CreateServiceAccountKey'
ORDER BY timestamp DESC;
```

En una org "sana" (WIF, impersonation), **esto debería devolver 0 filas**. Cualquier resultado es ticket.

### 6.3 Policy Denied (acceso bloqueado por VPC-SC u Org Policy)

```sql
SELECT
  timestamp,
  resource.labels.project_id AS project,
  protoPayload.authenticationInfo.principalEmail AS who,
  protoPayload.methodName AS what,
  protoPayload.status.message AS why
FROM `LOG_SINK_PROJECT.audit_logs.cloudaudit_googleapis_com_policy_*`
WHERE
  _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', CURRENT_DATE())
ORDER BY timestamp DESC
LIMIT 100;
```

## 7. Trade-off: BigQuery sink vs Pub/Sub sink

| | **BigQuery sink** | **Pub/Sub sink** |
|---|---|---|
| Para qué | Análisis SQL, retención, compliance. | Streaming hacia SIEM externo (Splunk, Datadog), reacción en tiempo real. |
| Latencia | Minutos (batch). | Segundos. |
| Costo | Storage + query. | Pub/Sub volume + lo que haga el consumer. |
| Idempotente al reset | Sí (sink reconstruible). | No (los mensajes consumidos se van). |

En orgs grandes se tiene **ambos**: BigQuery para analytics y compliance; Pub/Sub para el SIEM en real-time.

## 8. Preguntas de autocomprobación

1. ¿Por qué el sink org-wide necesita `--include-children` y qué pasa si lo omites?
2. ¿Qué permiso IAM necesita el service account creado por el sink en el dataset destino?
3. Si Data Access logs no están activos en el project origen, ¿la tabla `cloudaudit_googleapis_com_data_access_*` existirá vacía o no existirá?
4. Un atacante compromete un rol con `roles/logging.admin` en un workload project. ¿Puede borrar los logs ya exportados al sink? ¿Y los Admin Activity logs en origen?
5. ¿Qué query corres si quieres saber "qué proyectos tienen Data Access logs activos" (sin consultar la config, solo mirando el dataset)?
