# Recursos — az-08

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso (consolas, nombres y pricing cambian con frecuencia en Azure Monitor).

## Oficiales (Microsoft Learn)

- **Azure Monitor overview**: `https://learn.microsoft.com/azure/azure-monitor/overview`
- **Log Analytics Workspace design**: `https://learn.microsoft.com/azure/azure-monitor/logs/workspace-design`
- **Pricing (Monitor)**: `https://azure.microsoft.com/pricing/details/monitor/`
- **KQL reference**: `https://learn.microsoft.com/kusto/query/`
- **Scheduled Query Rules REST schema**: `https://learn.microsoft.com/rest/api/monitor/scheduled-query-rules`
- **Diagnostic Settings REST schema**: `https://learn.microsoft.com/rest/api/monitor/diagnostic-settings/create-or-update`
- **Activity Log categories**: `https://learn.microsoft.com/azure/azure-monitor/essentials/activity-log`
- **Action Groups**: `https://learn.microsoft.com/azure/azure-monitor/alerts/action-groups`

## Application Insights

- **Workspace-based App Insights**: `https://learn.microsoft.com/azure/azure-monitor/app/create-workspace-resource`
- **Azure Monitor OpenTelemetry Distro (Python)**: `https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable?tabs=python`
- **OpenTelemetry Collector + Azure Monitor exporter**: `https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/azuremonitorexporter`
- **Semantic conventions (OTel)**: `https://opentelemetry.io/docs/specs/semconv/`

## AKS

- **Container Insights**: `https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-overview`
- **Managed Prometheus + Managed Grafana**: `https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-overview`

## Lecturas de referencia

- Microsoft "Well-Architected Framework — Operational Excellence pillar": `https://learn.microsoft.com/azure/well-architected/operational-excellence/`
- Blog "Azure Monitor cost optimization": patterns oficiales (buscar la edición más reciente en techcommunity.microsoft.com).
- Charlas de **Ignite** sobre Azure Monitor y Sentinel (YouTube, última edición).

## Para el curso previo (contexto)

- Si no completaste `az-04`, al menos lee la sección de "Container Apps + App Insights" de su lección.
- Si no completaste `az-07`, al menos entiende qué es Container Insights (DaemonSet + workspace).

## Checklist de verificación requerida en Fase 4

- Estado del **Azure Monitor Agent (AMA)** como reemplazo del **Log Analytics Agent (MMA)** — MMA está en deprecación, calendario de retirada confirmado.
- Vigencia de la **API version** usada en los JSON de ejemplo (`scheduledQueryRules` y `diagnosticSettings` evolucionan en preview/GA).
- Precios actuales de Log Analytics (ingestion, Basic Logs, Archive) en la región del cliente.
- Estado de **Managed Prometheus** y de **Managed Grafana** (GA desde 2023; features nuevos cada quarter).
- Nombre actual del *add-on* de AKS (Container Insights sigue siendo el nombre pero el agente subyacente migró a AMA).
- Catálogo vigente de **categorías de Activity Log** (puede incorporar nuevas con el tiempo).
