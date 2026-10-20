# az-08 — Observabilidad con Azure Monitor, Application Insights y Activity Log

## Identificación

- **ID:** `az-08-observability-azure-monitor-app-insights-activity-log`
- **Curso:** `azure`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `az-04` (compute: Container Apps/Functions/App Service), `az-07` (AKS + Workload Identity).

## Objetivo

Instrumentar observabilidad **nativa de Azure** sobre un workload del capstone y conectarla al stack OSS: entender el paraguas **Azure Monitor** (Log Analytics Workspace + Metrics + Alerts + Workbooks), usar **Application Insights** como APM (basado en parte en OpenTelemetry), y centralizar el **Activity Log** vía **Diagnostic Settings**. Comparar explícitamente con **CloudWatch/X-Ray/CloudTrail** del lado AWS y traducir una **PromQL** típica a **KQL** equivalente.

## Alcance

Este módulo cubre:

- **Azure Monitor** como paraguas; qué es un **Log Analytics Workspace** y por qué todo acaba allí.
- **KQL** (Kusto Query Language): sintaxis mínima, operadores `where`, `summarize`, `project`, `extend`, `join`, `render`.
- **Application Insights** moderno (modo *workspace-based*): autocollect, OpenTelemetry exporter (`azure-monitor-opentelemetry`), spans y dependencias; `connection string` sobre `instrumentation key` legacy.
- **Metrics** (platform + custom): umbrales, agregaciones (`Avg`, `Sum`, `Count`, `Max`).
- **Alertas**: tres sabores — *metric alerts*, *log alerts* (sobre KQL de Log Analytics / App Insights), *activity log alerts*; **Action Groups** como destino (email, webhook, Logic App, Functions, ITSM).
- **Activity Log** (equivalente a CloudTrail para el management plane): categorías (`Administrative`, `Security`, `ServiceHealth`, `Alert`, `Autoscale`, `Policy`), *exportación continua* a Log Analytics / Storage / Event Hub.
- **Diagnostic Settings** como mecanismo universal para enviar logs/metrics de **cualquier recurso** a un sink.
- **Container Insights** para AKS (resumen; el detalle vive en `az-07`).
- Modelo de **costo** de Log Analytics (ingestion GB-based, retention tiering, *basic* vs *analytics* tables, Archive) y cómo reducirlo.
- Comparación de nomenclatura y servicios: CloudWatch Logs ↔ Log Analytics; CloudWatch Metrics ↔ Metrics; CloudTrail ↔ Activity Log; X-Ray ↔ App Insights distributed tracing.

Lo que **no** cubre:

- La parametrización completa de **Microsoft Sentinel** (SIEM/SOAR sobre Log Analytics) — se roza en `az-10`.
- **Defender for Cloud** CSPM/CWPP → `az-10`.
- Dashboards avanzados con **Workbooks** JSON (se menciona, no se entrega).
- Métricas prometheus-managed (**Managed Prometheus** + Managed Grafana) más allá de una mención.

Este módulo es **mayoritariamente conceptual + archivos JSON y KQL + walkthrough escrito**. **No** se provisiona nada en una suscripción real. Las dos actividades son independientes y se validan estructuralmente con `bash`, `jq` y `python3` sobre archivos locales.

## Materiales

- **`theory/lesson.md`** — lección con 10 secciones.
- **`examples/`** — ejemplos de lectura y análisis (no ejecución):
  - `01-app-insights-fastapi/` — walkthrough OpenTelemetry → Azure Monitor en una app FastAPI de ejemplo.
  - `02-kql-essentials/` — KQL mínimo, mapeo PromQL → KQL y SQL → KQL.
  - `03-activity-log-to-la-workspace/` — Diagnostic Settings de la suscripción enviando Activity Log a Log Analytics.
- **`activities/`** — dos actividades **independientes**:
  - `01-instrument-capstone-with-app-insights/` — walkthrough OTel + alert rule JSON + queries KQL + workspace JSON, todo validado estructuralmente.
  - `02-trim-la-cost/` — plan de reducción de coste de Log Analytics con `diagnostic-settings.json` filtrado y queries KQL de auditoría de ingesta.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre *metric alert* y *log alert*; por qué App Insights workspace-based reemplaza al modo *classic*; por qué el Activity Log vive separado de los logs de recurso; qué significa que KQL sea un lenguaje de *pipelines*. |
| Operativa (sin infra) | Escribir una regla de alerta como JSON ARM; redactar una consulta KQL de ventana temporal; definir un `diagnosticSettings` filtrado por categoría. |
| Arquitectónica | Decidir un workspace centralizado vs por workload; justificar retention tiering; traducir una PromQL típica a KQL equivalente. |

## Criterios de evaluación

- Convierte una PromQL (p. ej. `rate(http_requests_total{status=~"5.."}[5m])`) a KQL equivalente sobre `AppRequests`.
- Explica por qué el `connection string` reemplaza al `instrumentation key` en App Insights moderno.
- Diseña una `diagnosticSettings` filtrada por categoría para no ingerir todo el ruido en Log Analytics.
- Nombra las 6 categorías del Activity Log y para qué sirve cada una.
- Entrega las dos actividades con sus validadores estructurales terminando en **`0 issue(s)`**.

## Entregables

- Actividad 01: `otel-walkthrough.md`, `log-analytics-workspace.json`, `app-insights-alert.json`, `kql-queries.kql`, `README-INTENT.md`.
- Actividad 02: `cost-trim-plan.md`, `diagnostic-settings.json`, `la-cost-queries.kql`, `README-INTENT.md`.

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto, JSON y KQL. **No** se requiere suscripción Azure activa, ni *tenant ID* ni *subscription ID* reales. Si en una fase posterior decides provisionar lo diseñado:

- **Log Analytics Workspace**: `~2.76 USD/GB` ingerido (región varía) + retention sobre 31 días. Es el componente dominante en la factura de observabilidad.
- **Application Insights**: factura contra el workspace al que está asociado (ya no hay precio separado en el modo *workspace-based*).
- **Metrics** platform: gratis los primeros 150 MB; custom metrics tienen tarifa.
- **Alertas**: 10 metric alerts gratis / suscripción; luego ~0.10 USD/alert/mes. Log alerts se facturan por ejecución de query.
- **Activity Log**: la retención de 90 días en la plataforma es gratis; **exportar** a Log Analytics es lo que incurre costo (de ingesta).

## Siguiente módulo

→ `az-09-multi-subscription-management-groups-azure-policy-landing-zone` — gobernanza multi-subscription con Azure Policy y CAF Landing Zone.
