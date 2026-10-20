# REFERENCE — az-08-01 (intent + referencia semántica)

> Comparar con los archivos en este mismo `solution/` después de haber producido tu propia versión. El validador cubre estructura; la **corrección conceptual** se evalúa aquí.

## Resumen

Entregamos cinco artefactos para que `checkout` llegue a producción con observabilidad sana:

| Fichero | Qué representa |
|---------|----------------|
| `otel-walkthrough.md` | Guía reproducible para instrumentar la app con OTel → App Insights. |
| `log-analytics-workspace.json` | Workspace centralizado del entorno de producción. |
| `app-insights-alert.json` | Scheduled Query Rule sobre `AppRequests` para 5xx sostenidos. |
| `kql-queries.kql` | Queries del *playbook* del on-call. |
| `README-INTENT.md` | Documento de intención por archivo (justifica el *por qué*). |

---

## otel-walkthrough.md — decisiones

- **Distro oficial** (`azure-monitor-opentelemetry`) en vez de `opencensus-ext-azure` (legacy). Razón: OTel estandar + migración futura a otros backends sin tocar código.
- **Connection string** (no `instrumentation_key`): además del ikey, lleva `IngestionEndpoint` y `LiveEndpoint` — necesarios en regiones sovereign y para Live Metrics.
- **Direct exporter** (no Collector) para el walkthrough — es la mínima dependencia. Se menciona Collector como *next step*.
- **Verificación con KQL**: la señal de que todo funciona es ver filas en `AppRequests` y `AppDependencies` tras hacer tráfico — un `print()` no basta.

Autocollect: FastAPI + httpx + requests + sqlalchemy están autoinstrumentados; cualquier span custom se añade con `tracer.start_as_current_span`.

---

## log-analytics-workspace.json — decisiones

- `sku: PerGB2018`: pago por GB. Para empezar es correcto; se migra a *commitment tier* cuando se superen 100 GB/día.
- `retentionInDays: 30`: el default facturado (es también el default gratis en workspaces nuevos). Elevar a 90 solo si Security lo requiere; si no, mover histórico a Archive.
- `publicNetworkAccessForIngestion: Enabled`: permite ingesta desde workloads en Container Apps / AKS sin pelearse con Private Link en etapas tempranas; en producción endurecida se restringe con **Private Link** y `publicNetworkAccess: Disabled`.
- `publicNetworkAccessForQuery: Enabled`: necesario para que el on-call pueda consultar desde el portal fuera de la VNet corporativa.

Alternativas descartadas:
- `sku: CapacityReservation` con compromiso diario — prematuro con tráfico aún no estimado.
- `retentionInDays: 730` — paga por días que nunca se consultarán.

---

## app-insights-alert.json — decisiones

- `scheduledQueryRules` (no `metricAlerts`): porque la señal "ratio de 5xx sostenido en 15 min" se expresa mejor en KQL que como umbral sobre `requests/failed` crudo.
- `severity: 2` (warning). Un 5xx aislado no es Sev1; mantener Sev1 para páginas que despiertan a nadie.
- `evaluationFrequency: PT5M` + `windowSize: PT15M`: ventana solapada que detecta patrones sin disparar por outliers de un minuto.
- `failingPeriods: { 1, 1 }`: la primera evaluación que supere el umbral dispara. Para alertas más tolerantes al ruido, subir a `{ 3, 2 }` (3 periodos consecutivos, mínimo 2 fallando).
- `scopes` apunta al **workspace**, no al componente App Insights, porque App Insights workspace-based ya reside en el workspace y es ahí donde se evalúa el KQL.
- `actions.actionGroups: []`: deliberadamente vacío en el ejemplo (no hay AG creado); en Fase 4 se enlaza con el AG real `ag-platform-oncall`.

---

## kql-queries.kql — decisiones

Las tres queries cubren las tres preguntas del on-call:

1. **"¿Se están degradando los usuarios?"** → error_rate por minuto.
2. **"¿Es latencia o es errores?"** → p95/p99 por endpoint.
3. **"¿Qué request falló cuando esta excepción apareció?"** → `join` entre `AppExceptions` y `AppRequests` por `OperationId`.

**Patrones didácticos**:

- `bin(TimeGenerated, 1m)`: alineamos al minuto para que el gráfico no tenga saltos.
- `countif(...)` para errores en vez de un `where` + `summarize` paralelo (más legible).
- `percentile(DurationMs, 95)` + `percentile(DurationMs, 99)` juntos — más barato que ejecutar dos queries.
- `join kind=inner (AppRequests) on OperationId` — correlación clásica. Se puede refinar con `project-away` para quitar columnas de ruido.

---

## README-INTENT.md — decisiones

Un README-INTENT per fichero (no un `ANALYSIS.md`, por convención de este repo) es la referencia que lee quien tome tu PR en Fase 4 y lo convierta a Terraform.

Debe tener:

- Sección `## otel-walkthrough` justificando distro OTel.
- Sección `## log-analytics-workspace` justificando sku + retention + accesos.
- Sección `## app-insights-alert` justificando ventana + severidad + umbral.
- Sección `## kql-queries` describiendo quién consume cada query.
- Mención explícita de **OpenTelemetry**, **Application Insights**, **Log Analytics**, **KQL**.

Nunca incluyas GUIDs reales de tenant/suscripción. Usa `REDACTED-...`.
