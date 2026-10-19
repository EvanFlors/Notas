# Ejemplo 02 — Log Analytics sobre un bucket `_Default`

> Walkthrough. Lectura y análisis. Sin ejecución. Objetivo: entender cómo **convertir un log bucket en una tabla SQL** sin crear un sink y qué cosas se pueden resolver con queries ad-hoc.

## 1. Qué es Log Analytics y qué no es

| | **Log Analytics** | **Sink a BigQuery** |
|---|---|---|
| ¿Duplica datos? | **No**. Query sobre el bucket. | **Sí**. Copia los logs al dataset BigQuery. |
| ¿Pricing? | Scan BigQuery sobre los datos del bucket. | Storage + queries BigQuery, además de la ingesta de logs. |
| ¿Retention? | Misma que el log bucket (max 3650 días). | Retention a tu criterio en BigQuery (puede ser años). |
| ¿JOINs con tablas externas? | **Sí**, con tablas en el mismo project o accesibles. | **Sí**. |
| ¿Cuándo elegirlo? | Queries ocasionales, debugging, "¿cuántos 5xx hubo el martes?" | Dashboards continuos, reporting, compliance a 5 años. |

## 2. Activar Log Analytics (walkthrough — no ejecutes)

```bash
# PROJECT_ID = placeholder. NO existe un project real asociado.
gcloud logging buckets update _Default \
  --location=global \
  --project=PROJECT_ID \
  --enable-analytics
```

A partir de ahí, en la consola:

- Logs Explorer → "Log Analytics" (pestaña).
- Editor SQL con autocompletado sobre los campos del log.
- La "tabla" virtual se llama `project.global._Default._AllLogs`.

## 3. Queries de ejemplo (walkthrough)

### 3.1 Top 10 errores 5xx por service (última hora)

```sql
SELECT
  resource.labels.service_name AS service,
  COUNT(*) AS errors
FROM `PROJECT_ID.global._Default._AllLogs`
WHERE
  timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  AND resource.type = 'cloud_run_revision'
  AND CAST(JSON_VALUE(httpRequest.status) AS INT64) >= 500
GROUP BY 1
ORDER BY errors DESC
LIMIT 10;
```

### 3.2 Latencia p95 por endpoint

```sql
SELECT
  JSON_VALUE(httpRequest.requestUrl) AS url,
  APPROX_QUANTILES(CAST(REGEXP_EXTRACT(JSON_VALUE(httpRequest.latency), r'^(\d+(?:\.\d+)?)') AS FLOAT64), 100)[OFFSET(95)] AS p95_sec
FROM `PROJECT_ID.global._Default._AllLogs`
WHERE
  timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 MINUTE)
  AND resource.type = 'cloud_run_revision'
GROUP BY 1
ORDER BY p95_sec DESC
LIMIT 20;
```

### 3.3 Who did what (join con audit logs si viven en el mismo bucket)

```sql
SELECT
  timestamp,
  JSON_VALUE(protoPayload.authenticationInfo.principalEmail) AS who,
  JSON_VALUE(protoPayload.methodName) AS what,
  resource.labels.project_id AS project
FROM `PROJECT_ID.global._Default._AllLogs`
WHERE
  timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND logName LIKE '%cloudaudit.googleapis.com%activity%'
  AND JSON_VALUE(protoPayload.methodName) LIKE 'google.iam.admin.%'
ORDER BY timestamp DESC
LIMIT 100;
```

### 3.4 Noisy sources (para decidir dónde poner exclusion filters)

```sql
SELECT
  resource.type,
  logName,
  COUNT(*) AS n,
  SUM(IFNULL(length(textPayload), 0)
      + IFNULL(length(TO_JSON_STRING(jsonPayload)), 0)) AS approx_bytes
FROM `PROJECT_ID.global._Default._AllLogs`
WHERE timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
GROUP BY 1, 2
ORDER BY approx_bytes DESC
LIMIT 20;
```

Esta query es **la primera que corres cuando la factura de Logging se dispara**. Suele revelar: health checks, debug logs olvidados, VPC flow logs sin filtrar.

## 4. Cuándo NO usar Log Analytics

- **Si el dashboard se consulta cada 5 min 24×7**: el scan por consulta en Log Analytics se suma; probablemente sale mejor una **log-based metric** + Cloud Monitoring dashboard.
- **Si necesitas retention > 3650 días**: el bucket se queda corto; necesitas sink a BigQuery o GCS Coldline.
- **Si quieres `JOIN` con un dataset BigQuery grande en otro project**: posible, pero suele ir mejor copiando el log al dataset con un sink y luego haciendo el JOIN local.

## 5. Pricing mental model

Log Analytics se factura como un **BigQuery query on-demand** sobre los datos del bucket. Significa:

- `SELECT COUNT(*) ... WHERE timestamp > NOW() - 1h` escanea solo esa partición temporal (barato).
- `SELECT * FROM _AllLogs` escanea **todo el bucket** (puede ser caro).

Siempre `WHERE timestamp > ...` y siempre proyecta columnas específicas (nunca `SELECT *` en producción).

## 6. Interacción con sinks

Puedes tener **ambos**: Log Analytics activo sobre `_Default` **y** un sink hacia BigQuery para los `cloudaudit.googleapis.com/activity` que quieras conservar 400 días en formato particionado. No se duplican los logs en el bucket; el sink **copia hacia el destino externo**.

## 7. Preguntas de autocomprobación

1. ¿Por qué un `SELECT *` en Log Analytics puede ser materialmente más caro que la misma query en Logs Explorer con filtros?
2. Si activas Log Analytics y luego **reduces la retention del bucket** de 30 a 7 días, ¿qué pasa con las queries históricas?
3. En la query §3.4, ¿qué agregarías al `GROUP BY` para separar logs por severidad y así priorizar excluir los `INFO`?
4. Un auditor pide "quién leyó el bucket `prod-pii` ayer". ¿Qué prerrequisito debió activarse para que esa información esté en los logs?
5. ¿Cuándo prefieres **log-based metric + dashboard** antes que **Log Analytics query en dashboard**?
