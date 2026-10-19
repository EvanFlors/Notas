# README-INTENT — az-08-02

Documento de intención por archivo. El plan dice *qué hacer*; aquí explico *por qué así* y qué asumimos.

## Resumen

Plan de reducción de **~42%** del coste del Log Analytics Workspace `la-shared-prod` apoyado en cinco palancas estándar: `diagnosticSettings` filtradas, `Basic Logs`, `Archive`, `sampling` y `dailyQuotaGb` como daily cap. El diagnóstico y la medición se hacen con **KQL** contra la tabla `Usage`.

## cost-trim-plan

- **Diagnóstico cuantitativo primero**: no se recortan tablas a ciegas. Las queries sobre `Usage` ordenadas por `IsBillable == true` dan el ranking real.
- **Cinco palancas con nombres convencionales** (los que la documentación oficial de Azure Monitor usa): `diagnosticSettings` filtrados, `Basic Logs`, `Archive`, `sampling` (adaptive en App Insights + tail en OTel Collector), `dailyQuotaGb`.
- **Impacto estimado por palanca** con hipótesis explícita (−25% / −8% / −3% / −6% / solo picos → ~−42% total).
- **Plan por semanas** con dueño por paso y medición ex-post con las mismas queries del diagnóstico.
- **Riesgos** nombrados: perder señal, romper queries existentes, perder outliers por sampling, ciego por `dailyQuotaGb` en incidente.

## diagnostic-settings

- Recurso ARM `Microsoft.Insights/diagnosticSettings` (Diagnostic Settings a nivel recurso) sobre un **Application Gateway** como caso de uso típico.
- `workspaceId` apunta al workspace de observabilidad (NO al de seguridad), con placeholders `REDACTED-SUB-ID` — nunca GUIDs reales.
- `logs`: `ApplicationGatewayAccessLog` **on**, `ApplicationGatewayFirewallLog` **on**, `ApplicationGatewayPerformanceLog` **off**. Las dos primeras alimentan alertas y forensics; la tercera es ruido redundante con Metrics platform.
- `metrics`: `AllMetrics` **off** — las platform metrics ya están disponibles gratis en Monitor Metrics sin pasar por el workspace.
- Patrón generalizable: por cada tipo de recurso, listar categorías conocidas y decidir una por una.

## la-cost-queries

Cinco queries, cubriendo:

1. **Top data types por GB** (`Usage` + `sum(Quantity) / 1024.0`) — base del ranking.
2. **Serie temporal por día** — detecta picos y campañas.
3. **Top emisores en `AzureDiagnostics`** — por `_ResourceId`, con `estimate_data_size` para aproximar bytes.
4. **GB por Solution** — distingue Insights vs ContainerInsights vs Security.
5. **Agent run-away detection** — compara baseline 7–14 días vs último 7 días por `DataType` y detecta ratios ≥ 2.

Todas sobre tablas documentadas (`Usage`, `AzureDiagnostics`) con operadores KQL estándar (`summarize`, `top`, `join`, `bin`).

## Qué NO hace esta actividad

- No aplica Terraform (eso es Fase 4).
- No toca `Microsoft.Insights/dataCollectionRules` (DCRs) — se mencionan como extensión; son la palanca más fina para filtrado columna-a-columna.
- No ajusta policy de workspace (Private Link, `disableLocalAuth`) — eso es `az-10` DevSecOps.
