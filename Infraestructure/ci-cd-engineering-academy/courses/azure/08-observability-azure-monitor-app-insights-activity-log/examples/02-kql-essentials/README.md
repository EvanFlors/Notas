# Ejemplo 02 — KQL esencial (y mapeo PromQL/SQL → KQL)

> Lectura y análisis. Sin ejecución. Objetivo: salir de aquí con un **cheatsheet** que te deje escribir el 80% de las queries operativas sin googlear.

## 1. Modelo mental

- KQL es un lenguaje de **pipelines**: `Tabla | op1 | op2 | op3`.
- La tabla es siempre lo primero. **No** hay un `FROM` suelto.
- Cada operador transforma la tabla en una nueva tabla (schema-on-read para columnas `dynamic`).
- Es **case-sensitive** en nombres de columna y de tabla.

## 2. Operadores esenciales

| Operador | Qué hace | Ejemplo |
|----------|----------|---------|
| `where` | Filtra filas. | `where TimeGenerated > ago(5m)` |
| `project` | Selecciona/renombra columnas (como `SELECT`). | `project Time=TimeGenerated, Url, DurationMs` |
| `project-away` | Descarta columnas específicas. | `project-away _ResourceId` |
| `extend` | Calcula columnas nuevas. | `extend latency_s = DurationMs / 1000.0` |
| `summarize ... by ...` | Agrupa y agrega (como `GROUP BY`). | `summarize avg(DurationMs) by bin(TimeGenerated, 1m)` |
| `join kind=... on ...` | Join entre dos tablas. | `AppExceptions \| join kind=inner (AppRequests) on OperationId` |
| `union` | Concatena dos tablas con mismo schema. | `union AppRequests, AppDependencies` |
| `top N by col desc` | Top-N (más eficiente que `sort \| take`). | `top 10 by avg_ms desc` |
| `sort by` | Ordena. | `sort by TimeGenerated asc` |
| `distinct col1, col2` | Únicos. | `distinct Url` |
| `make-series` | Rellena huecos temporales. | `make-series count() default=0 on TimeGenerated step 1m` |
| `render` | Hint de visualización en el portal. | `render timechart` |

## 3. Funciones temporales

```kql
ago(5m)         // hace 5 minutos
ago(1h)         // hace 1 hora
ago(1d)         // hace 1 día
now()           // ahora
bin(TimeGenerated, 1m)   // alinea al minuto
startofday(now())        // 00:00 UTC hoy
datetime(2026-01-01)     // literal
format_datetime(now(), 'yyyy-MM-dd HH:mm')
```

## 4. Agregaciones típicas (dentro de `summarize`)

```kql
count()                   // número de filas
dcount(UserId)            // distintos aproximados (HyperLogLog)
dcountif(UserId, Success == false)
sum(Bytes)
avg(DurationMs)
min(DurationMs), max(DurationMs)
percentile(DurationMs, 95)
percentiles(DurationMs, 50, 90, 95, 99)
arg_max(TimeGenerated, *) // la última fila por grupo
countif(ResultCode startswith "5")
```

## 5. Mapeo SQL → KQL

| SQL | KQL |
|-----|-----|
| `SELECT a, b FROM T WHERE x > 1` | `T \| where x > 1 \| project a, b` |
| `SELECT COUNT(*) FROM T GROUP BY k` | `T \| summarize count() by k` |
| `SELECT a AS alias FROM T` | `T \| project alias = a` |
| `SELECT * FROM A JOIN B ON A.id = B.id` | `A \| join kind=inner B on id` |
| `SELECT * FROM T ORDER BY t DESC LIMIT 10` | `T \| top 10 by t desc` |
| `SELECT a, SUM(b) FROM T GROUP BY a HAVING SUM(b) > 100` | `T \| summarize s = sum(b) by a \| where s > 100` |

## 6. Mapeo PromQL → KQL (sobre `AppRequests` / `AppMetrics`)

| PromQL | KQL equivalente (hora pasada) |
|--------|-------------------------------|
| `rate(http_requests_total[5m])` | `AppRequests \| where TimeGenerated > ago(1h) \| summarize count() by bin(TimeGenerated, 1m) \| extend rps = count_ / 60.0` |
| `rate(http_requests_total{status=~"5.."}[5m])` | `AppRequests \| where TimeGenerated > ago(1h) and ResultCode startswith "5" \| summarize count() by bin(TimeGenerated, 1m)` |
| `histogram_quantile(0.95, http_request_duration_seconds_bucket)` | `AppRequests \| summarize p95 = percentile(DurationMs, 95) by bin(TimeGenerated, 1m)` |
| `sum by (service)(rate(http_requests_total[5m]))` | `AppRequests \| summarize count() by AppRoleName, bin(TimeGenerated, 1m)` |
| `up == 0` | `Heartbeat \| summarize last_seen = max(TimeGenerated) by Computer \| where last_seen < ago(5m)` |

**Pérdida conceptual:** PromQL es *rate-first* y maneja contadores acumulados nativamente; KQL es *log-first* y maneja eventos — para "contadores" cuentas filas. Son modelos distintos aunque alcanzables.

## 7. Trampas frecuentes

1. **Case-sensitivity**: `apprequests` no es `AppRequests`. El portal autocompleta pero el script sí falla.
2. **Agregación vs operador**: `count()` es función dentro de `summarize`; `count` por sí mismo colapsa toda la tabla en una fila con el total.
3. **`has` vs `contains`**: `has` es *token-based* (más rápido, no detecta substrings); `contains` es substring puro.
4. **`parse_json` para campos anidados**: si recibes un JSON como string, `parse_json(col).field` o `tostring(parse_json(col).field)`.
5. **`let` para parametrizar**: no es `SET`; es declaración perezosa:

   ```kql
   let threshold = 500;
   let window = 15m;
   AppRequests
   | where TimeGenerated > ago(window)
   | summarize p95 = percentile(DurationMs, 95) by AppRoleName
   | where p95 > threshold
   ```

## 8. Patrones listos para copiar

**Tabla más cara (ingesta por GB)** — útil en la actividad `02-trim-la-cost`:

```kql
Usage
| where TimeGenerated > ago(7d)
| where IsBillable == true
| summarize GB = sum(Quantity) / 1024.0 by DataType
| top 10 by GB desc
```

**Alertas disparadas en 24h**:

```kql
AlertsManagementResources
| where properties.essentials.startDateTime > ago(1d)
| summarize count() by tostring(properties.essentials.severity),
                      tostring(properties.essentials.monitorService)
```

**Cambios por operador en una suscripción (desde Activity Log)**:

```kql
AzureActivity
| where TimeGenerated > ago(1d)
| where OperationNameValue has "write" or OperationNameValue has "delete"
| summarize ops = count() by Caller, OperationNameValue
| top 20 by ops desc
```
