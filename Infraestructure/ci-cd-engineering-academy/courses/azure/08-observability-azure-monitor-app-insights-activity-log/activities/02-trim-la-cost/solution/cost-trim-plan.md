# Plan de reduccion de coste del Log Analytics Workspace `la-shared-prod`

## Contexto

Workspace de producción `la-shared-prod` factura **~900 USD/mes** (eastus-equivalente). Finance pide reducir el gasto ≥ **40%** sin perder las señales del playbook del on-call ni la auditoría de Security. El plan se ejecuta durante dos sprints (4 semanas) con medición antes/después vía la tabla `Usage`.

Supuestos:

- Workspace en modo `PerGB2018`, retención 30 días.
- ~85 GB/día ingeridos. ~2.76 USD/GB → ~234 USD/mes solo ingesta; el resto es retention + exports.
- La mayor parte del volumen viene de `AzureDiagnostics` (App Gateway + NSG flow logs) y `AppDependencies`.

## Diagnostico

Partimos de queries sobre la tabla `Usage` (ver `la-cost-queries.kql`). Hallazgos esperados:

| Rank | DataType                | GB/día aprox | % del total |
|------|-------------------------|--------------|-------------|
| 1    | `AzureDiagnostics`      | 32           | 38%         |
| 2    | `AppDependencies`       | 18           | 21%         |
| 3    | `ContainerLog` / `ContainerLogV2` | 12 | 14%        |
| 4    | `AppRequests`           | 9            | 11%         |
| 5    | `AzureActivity`         | 4            | 5%          |
| 6    | `Perf` / `InsightsMetrics` | 10        | 11%         |

El 38% viene de **categorías ruidosas** emitidas por recursos vía `diagnosticSettings` con `AllMetrics` + todas las categorías por default — mucho ruido, poca señal.

## Palancas

Cinco palancas, en orden de impacto esperado:

### 1. `diagnosticSettings` filtradas por categoría (impacto esperado −25%)

Hoy los `diagnosticSettings` de App Gateway y NSG están configurados con `AllMetrics: true` y todas las categorías habilitadas. **Ninguna** se usa en alertas. Pasar a:

- App Gateway: solo `ApplicationGatewayAccessLog` y `ApplicationGatewayFirewallLog`; apagar `ApplicationGatewayPerformanceLog` y `AllMetrics`.
- NSG: solo `NetworkSecurityGroupRuleCounter` (no `NetworkSecurityGroupEvent` detallado).

Ver `diagnostic-settings.json` adjunto como ejemplo del patrón.

### 2. Mover tablas de audit a **Basic Logs** (impacto esperado −8%)

Tablas candidatas: `AzureDiagnostics` sub-tipos de audit, `ContainerLogV2`. Basic Logs cuesta ~0.65 USD/GB vs 2.76 USD/GB (↓ ~75% en esos GBs), a cambio de solo soportar `where`, `project`, `extend` (sin `summarize` ni `join`) y 8 días de retención.

**No** mover: `AppRequests`, `AppDependencies`, `AppExceptions` — son fuente de alertas y necesitan `summarize`/`join`.

### 3. **Archive** para retención larga (impacto marginal, pero habilita subir ingest sin miedo)

Mover a Archive (0.025 USD/GB/mes) lo que *solo* se consulta para forensics puntual: `AzureActivity` histórico > 90 días, `ContainerLog` > 30 días.

### 4. **Sampling** en App Insights y OTel (impacto esperado −6%)

- App Insights: habilitar *adaptive sampling* al 20% de tope (`samplingPercentage` dinámico) en el componente `appi-checkout-prod`.
- OTel Collector: *tail sampling* para `AppDependencies` que terminen 2xx y < 100ms (ruido).

Riesgo controlado: percentiles agregados siguen siendo representativos; se pierde granularidad por trace individual.

### 5. `dailyQuotaGb` como **daily cap** financiero (impacto en picos)

Establecer `workspaceCapping.dailyQuotaGb: 80` como tope duro. Si se supera, se dejan de ingerir logs ese día (reset UTC 00:00). Es una red de seguridad, **no** una palanca de ahorro cotidiana — y crea un punto ciego el día que un incidente dispara el volumen.

### Resumen esperado

| Palanca | Ahorro |
|---------|--------|
| 1. Filtrado categorías | −25% |
| 2. Basic Logs | −8% |
| 3. Archive | −3% |
| 4. Sampling | −6% |
| 5. Daily cap | solo picos |
| **Total** | **~−42%** |

## Plan

| Semana | Acción | Dueño |
|--------|--------|-------|
| 1 | Diagnóstico firme con `la-cost-queries.kql` sobre 7 días reales. | SRE lead |
| 1 | Revisar los 10 `diagnosticSettings` más ruidosos. | Platform SRE |
| 2 | Rollout del nuevo `diagnostic-settings.json` por recurso vía Terraform. | Platform SRE |
| 2 | Habilitar Basic Logs en `ContainerLogV2` y audit sub-types. | Platform SRE |
| 3 | Habilitar adaptive sampling 20% en `appi-checkout-prod`. | App team (checkout) |
| 3 | Configurar Archive policy en `AzureActivity`. | Security |
| 4 | Medir con `Usage` vs baseline semana 0; reportar a Finance. | SRE lead |

## Riesgos

- **Perder señal en incidentes**: si se filtra una categoría que luego se necesita, hay que esperar al re-habilitado + ingesta nueva. Mitigación: lista de categorías "nunca apagar" (todo lo que participe en alertas).
- **Basic Logs rompe queries existentes**: dashboards del playbook que hagan `summarize` sobre una tabla migrada se romperán. Mitigación: inventario previo de queries en Workbooks + migrar en ventana de mantenimiento.
- **Sampling pierde outliers raros**: adaptive sampling descarta spans de alto volumen, no de alto interés. Mitigación: tail-sampling en Collector con reglas que preserven errores y spans > 1s.
- **`dailyQuotaGb` ciega al on-call**: si un incidente dispara 3x el volumen, la ingesta se corta justo cuando más se necesita. Mitigación: cap *holgado* (ej. 1.5x del normal), no apretado.
- **Factura es un KPI retrasado**: Finance ve la factura con 1 mes de retraso; mejor rastrear GB/día diario para feedback rápido.
