# README-INTENT — az-08-01

Documento de intención por archivo. El JSON y el KQL dicen *qué*; aquí explico *por qué* y *dónde se adjunta*.

## Resumen

Observabilidad reproducible para `checkout` sobre **Application Insights workspace-based**, con un **Log Analytics Workspace** compartido por entorno (`la-shared-prod`), una **Scheduled Query Rule** sobre KQL para 5xx sostenidos y queries de referencia para el *playbook* del on-call. Instrumentación con **OpenTelemetry** vía el distro oficial `azure-monitor-opentelemetry`.

## otel-walkthrough

- **Distro OTel oficial** (`azure-monitor-opentelemetry`) en vez del SDK clásico. Portabilidad y semantic conventions estándar.
- **Connection string** (no instrumentation key legacy): lleva `IngestionEndpoint` y `LiveEndpoint`, necesarios en regiones sovereign y para Live Metrics.
- Autocollect de FastAPI/httpx/sqlalchemy — no se decora cada ruta manualmente.
- Verificación con KQL contra `AppRequests` — nunca con `print()`.
- No se incluyen GUIDs reales de tenant/subscription/instrumentation key en el walkthrough: todo marcado como `REDACTED-...`.

## log-analytics-workspace

- Recurso ARM `Microsoft.OperationalInsights/workspaces`, API `2022-10-01`.
- `sku: PerGB2018` para empezar. Migramos a *CapacityReservation* cuando superemos 100 GB/día de ingesta.
- `retentionInDays: 30` — default facturado. Mover a Archive lo que requiera retención larga.
- `publicNetworkAccess` **Enabled** en ambos sentidos para evitar fricción en primeras iteraciones; en el próximo sprint pasa a Private Link con `Disabled`.
- `workspaceCapping.dailyQuotaGb: 5` — tope de seguridad financiero.
- Enlaza con el componente **Application Insights** `appi-checkout-prod` que vive en otro RG — ambos apuntando al mismo workspace (modo *workspace-based*).

## app-insights-alert

- Recurso ARM `Microsoft.Insights/scheduledQueryRules`.
- Elegido sobre `metricAlerts` porque la señal "ratio sostenido" se expresa mejor en KQL que como umbral sobre contadores crudos.
- `severity: 2` (warning). Para Sev1 reservamos "caída total" (health check 0 en 2 min consecutivos).
- Ventana `windowSize: PT15M` con `evaluationFrequency: PT5M`: solape razonable para patrón sostenido.
- `failingPeriods: {1,1}`: dispara en la primera evaluación por encima. Si Observamos *flapping*, subir a `{3,2}`.
- `scopes` apunta al **workspace** (`la-shared-prod`), no al componente App Insights, porque las tablas viven en el workspace.
- `actions.actionGroups: []` deliberadamente vacío — en Fase 4 se enlaza con el Action Group real `ag-platform-oncall` (email + webhook Slack + PagerDuty).
- `autoMitigate: true` para que la alerta se cierre sola cuando la condición cese.

## kql-queries

Cuatro queries, tres obligatorias para el playbook y una extra:

1. **Error rate por minuto** — señal principal del on-call.
2. **Percentiles p50/p95/p99 por endpoint** — para distinguir "todo lento" de "endpoint lento".
3. **`join` excepciones ↔ requests** por `OperationId` — base del timeline forense cuando salta la alerta.
4. **Top dependencies por p95** — para discernir si el culpable es la app o un backend upstream.

Todas usan `AppRequests` / `AppDependencies` / `AppExceptions`, `summarize`, `bin(TimeGenerated,...)`, `percentile(...)` y al menos un `join` — cubriendo el repertorio KQL mínimo que un ingeniero de guardia debe reconocer.

**Nota**: `KQL` es sensible a mayúsculas. Las queries están formateadas para portarse al runbook sin cambios.

## Lo que NO entrega esta actividad

- Managed Prometheus / Managed Grafana (fuera del alcance; mencionado en `theory/lesson.md`).
- Container Insights add-on para AKS (vive en `az-07`).
- Workbooks JSON de dashboards (se cita en el módulo pero no se entrega).
- Terraform (lo veremos en Fase 4; aquí entregamos solo ARM JSON y KQL).
