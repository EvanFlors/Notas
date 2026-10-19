# Ejemplo 03 — Billing export a BigQuery y queries base

**No se ejecuta nada.** Lectura y discusión. Las queries son plantillas listas para pegar en BigQuery.

## 1. Qué habilita el export

Al activar el export a BigQuery (Billing → Billing export → BigQuery export), GCP escribe cada día (o cada hora, según el modo) una tabla en el dataset elegido:

- `gcp_billing_export_resource_v1_<billing_account_id>` — detallado por recurso.
- `gcp_billing_export_v1_<billing_account_id>` — agregado por project+service+sku (más barato de consultar).

Schema clave:

| Columna | Tipo | Qué contiene |
|---------|------|--------------|
| `invoice.month` | STRING | `YYYYMM` |
| `project.id` | STRING | project id |
| `project.labels` | ARRAY<STRUCT<key,value>> | labels del project |
| `service.description` | STRING | ej. "Cloud Run" |
| `sku.description` | STRING | ej. "CPU Allocation Time" |
| `usage.amount` / `usage.unit` | FLOAT / STRING | consumo |
| `cost` | FLOAT | coste pre-descuentos |
| `credits` | ARRAY<STRUCT<name,amount,type>> | SUDs, CUDs, promos |
| `labels` | ARRAY<STRUCT<key,value>> | labels del recurso |
| `location.region` | STRING | región |
| `resource.name` | STRING | nombre del recurso (puede ser null) |

El **coste neto** es `cost + SUM(credits.amount)` (los credits vienen con signo negativo).

## 2. Query — coste por project y mes

```sql
SELECT
  project.id AS project_id,
  invoice.month AS month,
  SUM(cost) + SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)) AS net_cost_eur
FROM `my-project-123.billing_export.gcp_billing_export_v1_01ABCD_234567_89EFGH`
WHERE invoice.month = '202610'
GROUP BY project_id, month
ORDER BY net_cost_eur DESC;
```

## 3. Query — coste por label `workload`

```sql
SELECT
  (SELECT value FROM UNNEST(labels) WHERE key = 'workload') AS workload,
  SUM(cost) + SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)) AS net_cost_eur
FROM `my-project-123.billing_export.gcp_billing_export_resource_v1_01ABCD_234567_89EFGH`
WHERE invoice.month = '202610'
GROUP BY workload
HAVING workload IS NOT NULL
ORDER BY net_cost_eur DESC;
```

## 4. Query — top 10 SKUs

```sql
SELECT
  service.description AS service,
  sku.description AS sku,
  SUM(cost) AS gross_cost_eur
FROM `my-project-123.billing_export.gcp_billing_export_v1_01ABCD_234567_89EFGH`
WHERE invoice.month = '202610'
GROUP BY service, sku
ORDER BY gross_cost_eur DESC
LIMIT 10;
```

## 5. Query — coste del cluster `prod-autopilot`

```sql
SELECT
  invoice.month,
  SUM(cost) AS cost_eur
FROM `my-project-123.billing_export.gcp_billing_export_resource_v1_...`
WHERE service.description = 'Kubernetes Engine'
  AND (SELECT value FROM UNNEST(labels) WHERE key = 'goog-k8s-cluster-name') = 'prod-autopilot'
GROUP BY invoice.month
ORDER BY invoice.month;
```

## 6. Qué observar

- El coste **real** facturado está después de aplicar credits. Olvidarlo infla el número 10–30 %.
- Los labels son la pieza clave: sin disciplina de labels (`env`, `workload`, `cost-center`, `owner`), los análisis colapsan a "por project" y pierden granularidad.
- GKE Autopilot inyecta `goog-k8s-cluster-name` automáticamente — útil incluso si tu disciplina de labels aún no está perfecta.

## 7. Pregunta de discusión

Si un service account del pipeline deja de llevar label `env`, ¿cómo lo detectas antes de que se note en el reporte mensual?
