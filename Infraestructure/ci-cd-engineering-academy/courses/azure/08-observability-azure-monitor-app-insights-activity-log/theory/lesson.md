# az-08 — Observabilidad con Azure Monitor, Application Insights y Activity Log

> Lección profunda. Lee a lápiz, con el `README.md` del módulo abierto en paralelo. Al terminar debes poder abrir Azure Portal y moverte por el blade de Monitor sin perderte, y escribir una KQL razonable a mano.

---

## 1. ¿Qué es "Azure Monitor"?

Azure Monitor **no es un servicio** en el sentido estricto — es un **paraguas** que agrupa:

| Componente | Qué hace | Equivalente AWS |
|------------|----------|-----------------|
| **Log Analytics Workspace** | Datastore unificado de logs con **KQL** encima. | CloudWatch Logs + Logs Insights. |
| **Metrics** (platform + custom) | Series temporales a 1 min / 1 s, con 93 días de retención. | CloudWatch Metrics. |
| **Application Insights** | APM: requests, dependencies, exceptions, traces. | X-Ray + CloudWatch RUM/Synthetics. |
| **Alerts** | Reglas sobre metrics, logs o Activity Log. | CloudWatch Alarms + EventBridge. |
| **Workbooks** | Dashboards interactivos (JSON). | CloudWatch Dashboards. |
| **Activity Log** | Management plane (quién hizo qué en Azure). | CloudTrail. |
| **Diagnostic Settings** | *Pipe* universal: envía logs/metrics de **cualquier recurso** a un sink. | *EventBridge rules* + *Kinesis Firehose* + delivery streams. |

**Idea clave:** casi todo acaba, antes o después, en un **Log Analytics Workspace** si quieres consultarlo con KQL. Metrics vive aparte en una base de series temporales (no es KQL), pero puedes **traerlas al workspace** si necesitas unirlas con logs.

---

## 2. Log Analytics Workspace

Un **workspace** es:

- Un recurso ARM (`Microsoft.OperationalInsights/workspaces`).
- Multi-tenant por diseño: **una tabla por *source***, con esquema fijo (ej. `AppRequests`, `AppDependencies`, `AzureActivity`, `AzureDiagnostics`, `Heartbeat`, `Perf`, `Syslog`, `ContainerLog`, `KubePodInventory`...).
- Facturado por **GB ingeridos** (default pricing tier `PerGB2018`), con *commitment tiers* a partir de 100 GB/día para descuentos.
- Retención por tabla, **de 4 a 730 días en Analytics**; existe un tier **Basic Logs** más barato pero con query limitada (sólo `where`, `project`, `extend`, sin `summarize` ni `join`), y un tier **Archive** (hasta 12 años) donde recuperar un rango de tiempo requiere un *search job*.

**Decisión arquitectónica clave:** ¿un workspace central o uno por workload?

- **Central**: queries cross-workload fáciles, costo uniforme, *gobernanza* más simple. Problema: ruidosos vecinos y Explosión de permisos.
- **Por workload**: aislamiento de costo y de RBAC, pero `join` entre workspaces exige el operador `workspace()` y degrada performance.
- **Patrón recomendado**: un workspace **por entorno** (`la-shared-dev`, `la-shared-prod`), y uno adicional **para seguridad** (destino de Sentinel + Activity Log) para que Finance no vea logs de auditoría y Security no vea ruido operacional.

---

## 3. KQL en 10 minutos

**KQL** (Kusto Query Language) es un lenguaje de *pipelines* (como PowerShell/Elvish). Lees de arriba abajo, cada operador transforma la tabla.

```kql
AppRequests
| where TimeGenerated > ago(1h)
| where Success == false
| summarize count() by bin(TimeGenerated, 5m), ResultCode
| render timechart
```

- **Tabla primero** (no `SELECT ... FROM`). La tabla a la izquierda; los operadores a la derecha.
- `|` encadena operadores (en vez de `AND`/`WHERE`/`GROUP BY` entremezclados).
- Operadores esenciales: `where`, `project`, `extend`, `summarize`, `join`, `union`, `top`, `sort`, `distinct`, `make-series`, `render`.
- Funciones temporales: `ago(5m)`, `now()`, `bin(TimeGenerated, 1m)`, `datetime()`.
- Agregaciones: `count()`, `sum()`, `avg()`, `percentile(X, 95)`, `dcount()`, `arg_max()`.

**Mapeo PromQL → KQL**:

| PromQL | KQL (sobre `AppRequests`) |
|--------|---------------------------|
| `rate(http_requests_total[5m])` | `summarize count() by bin(TimeGenerated, 1m) \| extend rps = count_ / 60.0` |
| `rate(http_requests_total{status=~"5.."}[5m])` | `where ResultCode startswith "5" \| summarize count() by bin(TimeGenerated, 1m)` |
| `histogram_quantile(0.95, http_request_duration_seconds_bucket)` | `summarize p95 = percentile(DurationMs, 95) by bin(TimeGenerated, 1m)` |
| `sum by (service) (rate(...))` | `summarize count() by AppRoleName, bin(TimeGenerated, 1m)` |

**Mapeo SQL → KQL** (atajo mental):

- `SELECT ... FROM T WHERE X GROUP BY Y` → `T | where X | summarize ... by Y`
- `SELECT col AS alias` → `project alias = col`
- `JOIN` → `join kind=inner (OtraTabla) on CommonKey`

**Trampa 1 — case-sensitive:** KQL es sensible a mayúsculas en nombres de columna y de tabla. `appRequests` **no** es `AppRequests`.

**Trampa 2 — operador vs función:** `count()` es una función de agregación dentro de `summarize`; `count` *solo* como operador terminal (`T | count`) devuelve una fila con el total.

**Trampa 3 — `.` no es acceso a campo:** para campos dinámicos usas `col.subfield` sólo si la columna es `dynamic`; en strings/JSON usas `parse_json(col).subfield` o `col[["subfield"]]`.

---

## 4. Application Insights

**App Insights clásico** (hasta 2020) tenía su propia DB y usaba una `instrumentation_key` (GUID). **App Insights moderno** es **workspace-based**: las tablas (`AppRequests`, `AppDependencies`, `AppExceptions`, `AppTraces`, `AppCustomEvents`, `AppMetrics`, `AppPerformanceCounters`, `AppAvailabilityResults`, `AppPageViews`) viven en un Log Analytics Workspace, y se identifica el componente con una **connection string** (`InstrumentationKey=...;IngestionEndpoint=https://<region>.in.applicationinsights.azure.com/;LiveEndpoint=...;ApplicationId=...`).

Autocollect en Python/Node/Java/.NET: con el SDK oficial, se auto-instrumentan requests HTTP entrantes, dependencies salientes (HTTP, SQL, cosmos, service bus, storage) y exceptions sin tocar el código del negocio.

**Modo OpenTelemetry (recomendado hoy):**

```python
# requirements.txt: azure-monitor-opentelemetry
from azure.monitor.opentelemetry import configure_azure_monitor
configure_azure_monitor(
    connection_string=os.environ["APPLICATIONINSIGHTS_CONNECTION_STRING"]
)
# A partir de aquí, FastAPI/Flask/requests/sqlalchemy están auto-instrumentados.
```

Esto arranca un **OTel SDK** con el **Azure Monitor OTel exporter**. Las ventajas sobre el SDK propietario viejo:

1. Portabilidad: la misma app exporta a Jaeger, Tempo, Datadog, etc., cambiando el exporter.
2. Semantic conventions estables (OTel 1.0+).
3. Ingesta llega como `AppRequests`/`AppDependencies`/`AppTraces` normal — no requiere cambios en el workspace.

**Collector pattern (producción grande):** aplicación → **OTel Collector** (sidecar o DaemonSet) → **Azure Monitor Exporter** → App Insights. Permite batching, filtering, tail sampling, atribución, redacción de PII.

---

## 5. Metrics (platform + custom)

**Platform metrics**: emitidas automáticamente por **cada recurso** (CPU de una VM, requests de un App Service, 2xx/5xx de un AppGw, memoria de un AKS node...). No se pagan, retención fija 93 días, resolución 1 min.

**Custom metrics**: emitidas por el workload vía SDK o Azure Monitor OTel exporter (que las envía a la tubería *custom metrics*). Tienen tarifa.

**Dimensiones**: hasta 10 por métrica (región, workload, versión, result code, status).

**Agregaciones** en el chart: `Avg`, `Sum`, `Min`, `Max`, `Count`. Elegir mal la agregación es la fuente #1 de alarmas tontas: para latencias usas `Avg` o percentiles; para errores usas `Sum` o `Count`; **nunca** `Avg` de un contador acumulado.

---

## 6. Alertas

Tres sabores distintos. Todos consumen un **Action Group** (recipientes).

### 6.1 Metric alerts (`Microsoft.Insights/metricAlerts`)

- Umbral sobre una métrica estándar o custom, evaluado cada 1 min.
- Severidades Sev0 (crítica) → Sev4 (informacional).
- Soporta *dynamic thresholds* (ML sobre histórico — útil para patrones estacionales).
- Barato (10 alertas gratis + ~0.10 USD/alerta/mes).

### 6.2 Log alerts / Scheduled Query Rules (`Microsoft.Insights/scheduledQueryRules`)

- Ejecuta una **KQL** cada N minutos sobre Log Analytics / App Insights y dispara si el resultado cumple una condición (número de filas, agregación, etc.).
- Útil cuando no hay métrica dedicada (ej. "más de 5 excepciones `TimeoutError` por minuto").
- Facturan por **ejecución de query**; cuidado con intervalos de 1 min sobre tablas grandes.

Esquema mínimo (ARM):

```json
{
  "type": "Microsoft.Insights/scheduledQueryRules",
  "apiVersion": "2023-03-15-preview",
  "properties": {
    "severity": 2,
    "enabled": true,
    "scopes": ["<workspaceResourceId>"],
    "evaluationFrequency": "PT5M",
    "windowSize": "PT15M",
    "criteria": {
      "allOf": [{
        "query": "AppRequests | where Success == false | summarize failed = count()",
        "timeAggregation": "Count",
        "operator": "GreaterThan",
        "threshold": 10,
        "failingPeriods": { "numberOfEvaluationPeriods": 1, "minFailingPeriodsToAlert": 1 }
      }]
    },
    "actions": { "actionGroups": ["<actionGroupId>"] }
  }
}
```

### 6.3 Activity Log alerts (`Microsoft.Insights/activityLogAlerts`)

- Disparan al observar una **operación** en la suscripción (ej. "alguien borró una NSG rule", "ServiceHealth: incidente en West Europe").
- No consultan KQL — reaccionan a eventos del Activity Log directamente.
- Son prácticamente gratis.

**Action Groups** (`Microsoft.Insights/actionGroups`): email, SMS, voice, webhook, Logic App, Azure Function, Event Hub, ITSM, Automation Runbook. En el día a día: email + webhook a Slack/PagerDuty + runbook.

---

## 7. Activity Log

Es el **registro inmutable del management plane** de la suscripción. Equivale a **CloudTrail Management Events** en AWS.

**6 categorías**:

| Categoría | Qué registra |
|-----------|--------------|
| `Administrative` | Create/Update/Delete de recursos; role assignments; policy assignments. |
| `Security` | Alertas de **Defender for Cloud**. |
| `ServiceHealth` | Incidentes de la plataforma Azure que afectan a tu suscripción. |
| `Alert` | Disparos de alertas (Monitor/Activity Log/SecOps). |
| `Autoscale` | Escalados automáticos (VMSS, App Service...). |
| `Policy` | Evaluaciones y resultados de Azure Policy. |
| `Recommendation` | Advisor recommendations. |
| `ResourceHealth` | Estado por recurso individual. |

**Lo que NO está en Activity Log** (no te confundas): los *data plane* calls (leer un blob, consultar Cosmos, ejecutar una query KQL) **no** aparecen aquí — van, si están habilitados, a los **Diagnostic Settings** de cada recurso.

Retención en la plataforma: **90 días**, gratis. Para retención larga o para hacer KQL contra el Activity Log, hay que **exportarlo a un Log Analytics Workspace** con un `diagnosticSettings` a nivel suscripción. La tabla resultante es `AzureActivity`.

---

## 8. Diagnostic Settings

Mecanismo universal: todo recurso Azure que emita logs/metrics tiene (o puede tener) una `diagnosticSettings` que define:

- **Sinks posibles**: Log Analytics Workspace, Storage Account (archivo), Event Hub (streaming → SIEM externo o Splunk), Partner solutions.
- **Qué** se envía: una lista de `logs` (por categoría) y de `metrics` (`AllMetrics` o filtradas).
- **Puede haber hasta 5 settings por recurso** → el patrón "LA + Storage archive + Event Hub a Splunk" es viable.

Esquema mínimo (ARM):

```json
{
  "type": "Microsoft.Insights/diagnosticSettings",
  "apiVersion": "2021-05-01-preview",
  "name": "to-log-analytics",
  "properties": {
    "workspaceId": "<workspaceResourceId>",
    "logs": [
      { "category": "Administrative", "enabled": true },
      { "category": "Policy",         "enabled": true }
    ],
    "metrics": [
      { "category": "AllMetrics", "enabled": false }
    ]
  }
}
```

Clave de **FinOps**: *categoría por categoría*. Mandar `AllMetrics` + todas las categorías de logs de cada recurso satura un workspace y aniquila el presupuesto. El default es "todo apagado", y hay que decidir **qué** vale la pena ingerir.

---

## 9. Container Insights (AKS)

Add-on oficial de AKS que:

- Despliega el **omsagent / AMA (Azure Monitor Agent)** como DaemonSet en el cluster.
- Enlaza con un Log Analytics Workspace.
- Rellena las tablas `ContainerLog`, `ContainerInventory`, `KubePodInventory`, `KubeNodeInventory`, `Perf`, `InsightsMetrics`.
- Habilita un blade "Container insights" con vistas pre-hechas (nodos, pods, controladores).

**Alternativas / complementos**:

- **Managed Prometheus** + **Managed Grafana**: para quien ya tiene operadores PromQL y quiere evitar re-aprender KQL para métricas.
- Patron híbrido: Prometheus para métricas, Log Analytics para logs y traces.

El detalle de instrumentación en AKS vive en `az-07`; aquí se cita como caso de uso.

---

## 10. Costo y comparación con CloudWatch

**Modelo mental de costo** (números orientativos — verificar en Fase 4):

- Log Analytics: **~2.76 USD por GB ingerido** (eastus) + retención incluida 31 días; cada día adicional, ~0.12 USD/GB/mes.
- Basic Logs: ~0.65 USD/GB (query limitada; ingest-only).
- Archive: ~0.025 USD/GB/mes (recuperas con search job pagado).
- Application Insights: factura contra el workspace (no hay precio aparte en modo *workspace-based*).
- Metrics platform: gratis; Custom metrics ~0.258 USD/million time-series ingested.
- Alertas: 10 metric alerts gratis / suscripción; log alerts facturan por *query execution*.

**Patrones de reducción**:

1. Filtrar `diagnosticSettings`: categorizar y apagar lo ruidoso (`AllMetrics` por defecto).
2. Mover tablas de audit a **Basic Logs** si solo se usan para forensics puntual.
3. Mandar a **Storage** (barato) lo que necesita retención larga pero no query diaria.
4. **Sampling** en App Insights (adaptive sampling: SDK descarta spans redundantes antes de ingerir).
5. KQL de inventario sobre `Usage` para detectar la tabla que domina la factura.

**Comparación**:

| CloudWatch (AWS) | Azure Monitor |
|------------------|---------------|
| Logs Insights (`fields`, `filter`, `stats`) | KQL (`where`, `project`, `summarize`) |
| CW Metrics (periodo 1 min / 1 s) | Monitor Metrics (1 min / 1 s) |
| X-Ray | App Insights (OTel-based) |
| CloudTrail Management Events | Activity Log |
| CloudTrail Data Events | Diagnostic Settings por recurso |
| CloudWatch Alarms | Metric Alerts / Log Alerts / Activity Log Alerts |
| SNS + Lambda target | Action Group + Logic App / Function |

**Conceptualmente**, la pieza "extra" en Azure es **Diagnostic Settings** como control plane universal del logging; en AWS esa labor se reparte entre *EventBridge rules*, *Kinesis Firehose* y *per-service logging configs* (ALB access logs, S3 access logs, VPC flow logs...).

---

## Lecturas rápidas de validación

- Si alguien dice *"activa CloudTrail para esto"* en Azure, traducción = *"añade un `diagnosticSettings` a esa suscripción enviando `Administrative` al workspace"*.
- Si alguien dice *"hazme un dashboard de errores por servicio en los últimos 15 min"*, pensar KQL + `AppRequests`.
- Si alguien dice *"alerta cuando se borre un RG"*, pensar **Activity Log Alert**, no metric alert.
- Si alguien dice *"instrumenta la app"*, pensar **Azure Monitor OpenTelemetry Distro**, no el SDK clásico.
