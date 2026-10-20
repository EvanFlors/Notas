# Actividad 01 — Instrumentar la app del capstone con App Insights, alertas y KQL

## 1. Identificación

- **ID:** `az-08-01-instrument-capstone-with-app-insights`
- **Tecnología:** `azure`
- **Módulo:** `az-08-observability-azure-monitor-app-insights-activity-log`
- **Dificultad:** advanced
- **Duración estimada:** 110–130 min
- **Tipo:** architecture (independent — sin dependencia de la actividad 02)

## 2. Contexto

El equipo de SRE necesita, antes de llevar `checkout` (la API del capstone) a producción en Container Apps / AKS, un **paquete de observabilidad reproducible**: cómo se instrumenta la app con OpenTelemetry hacia Application Insights, qué recursos Azure (Log Analytics Workspace, alertas) hay que crear, y qué queries KQL se usan para el *playbook* del equipo on-call.

Tu encargo: entregar un conjunto de archivos locales que, al revisarlos, un ingeniero externo pueda:

1. Instrumentar la app en 10 minutos siguiendo el walkthrough.
2. Entender qué workspace vamos a crear y por qué (sku, retention).
3. Ver las alertas en formato JSON ARM listas para traducir a Terraform en Fase 4.
4. Copiar KQL útiles al runbook.

**Importante**: no hay suscripción Azure real. No se despliega nada. No debes incluir *tenant ID* ni *subscription ID* reales — usa `REDACTED-TENANT-ID`, `REDACTED-SUB-ID`, `REDACTED-WORKSPACE-ID` o similares.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Escribir un walkthrough OTel → App Insights usando `azure-monitor-opentelemetry` y una `connection string`.
- Declarar un Log Analytics Workspace como JSON ARM (`Microsoft.OperationalInsights/workspaces`).
- Declarar una Scheduled Query Rule (`Microsoft.Insights/scheduledQueryRules`) sobre KQL.
- Escribir KQL que compute error rate, percentiles de latencia y que haga `join` para correlacionar excepciones con requests.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §3 KQL y §4–6 App Insights/Metrics/Alerts).
- Haber recorrido los tres `examples/` del módulo.
- Herramientas: `bash`, `jq` (parser JSON), `python3` (opcional para validaciones extra). Editor Markdown.

**Costos**: ninguno. Todo es papel + JSON + KQL local.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/az-08-01
cd /tmp/az-08-01
```

Puedes usar otro directorio, pero pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Entregables (nombres **exactos**)

1. `otel-walkthrough.md`
2. `log-analytics-workspace.json`
3. `app-insights-alert.json`
4. `kql-queries.kql`
5. `README-INTENT.md`

### 5.3 `otel-walkthrough.md`

Documento Markdown que explique paso a paso cómo instrumentar una app Python (FastAPI o Flask) con **OpenTelemetry → Azure Monitor**. Secciones **obligatorias** (el validador las busca):

- `# ` encabezado principal mencionando OpenTelemetry.
- `## Prerrequisitos` — Python 3.11+, `pip`, un workspace App Insights (puedes decir "simulado").
- `## Instalacion` o `## Install` — `pip install azure-monitor-opentelemetry` (mencionar literal el paquete).
- `## Configuracion` o `## Configuration` — mostrar `configure_azure_monitor(connection_string=...)`.
- `## Verificacion` o `## Verification` — mostrar al menos un KQL ejemplo que prueba que llega data (`AppRequests | ...`).

Contenido mínimo (el validador exige):

- Mención explícita de `connection string` (vs `instrumentation key` legacy).
- Mención de **al menos dos** tablas de App Insights (`AppRequests`, `AppDependencies`, `AppExceptions`, `AppTraces`).
- Un code fence con `configure_azure_monitor`.
- Un code fence con el KQL de verificación.
- NO debe contener strings que parezcan tenant/subscription reales (GUIDs completos como `12345678-1234-1234-1234-123456789012` están prohibidos; usa `REDACTED-...`).

### 5.4 `log-analytics-workspace.json`

JSON ARM de un Log Analytics Workspace. Requisitos:

- `type == "Microsoft.OperationalInsights/workspaces"`.
- `apiVersion` presente (p. ej. `2022-10-01` o `2023-09-01`).
- `name` string legible (p. ej. `la-shared-prod`).
- `location` string (`westeurope`, `northeurope`, etc.).
- `properties.sku.name` presente (p. ej. `PerGB2018`).
- `properties.retentionInDays` entero entre 30 y 730.
- `properties.publicNetworkAccessForIngestion` y `publicNetworkAccessForQuery` presentes.
- JSON parseable por `jq .`.

### 5.5 `app-insights-alert.json`

JSON ARM de una Scheduled Query Rule. Requisitos:

- `type == "Microsoft.Insights/scheduledQueryRules"`.
- `apiVersion` presente.
- `properties.severity` entero 0–4.
- `properties.enabled == true`.
- `properties.evaluationFrequency` en formato ISO 8601 (`PT5M`, `PT15M`...).
- `properties.windowSize` en formato ISO 8601.
- `properties.criteria.allOf` array con al menos un elemento que contenga `query` (un KQL válido como string).
- `properties.scopes` array con al menos un elemento. El elemento debe parecer un workspace resource id (`contains "/providers/Microsoft.OperationalInsights/workspaces/"`).
- `properties.actions.actionGroups` array (puede estar vacío, pero debe existir).

### 5.6 `kql-queries.kql`

Archivo con **al menos 3** consultas KQL separadas por `//---` o por comentarios. Requisitos:

- Al menos una query mencione `AppRequests`.
- Al menos una query use `percentile(` (percentiles de latencia).
- Al menos una query use `join` (correlación entre tablas).
- Al menos una query use `bin(TimeGenerated,` (bucket temporal).
- Al menos una query use `summarize`.

### 5.7 `README-INTENT.md`

Documento con una **sección por archivo** entregado. Secciones **obligatorias** (el validador las busca por nombre):

- `## otel-walkthrough`
- `## log-analytics-workspace`
- `## app-insights-alert`
- `## kql-queries`

Debe mencionar explícitamente:

- `OpenTelemetry` (literal).
- `Application Insights` (literal).
- `Log Analytics` (literal).
- `KQL` (literal).

## 6. Resultado esperado

- Los 5 archivos existen y están bien formados.
- `bash tests/validate.sh /tmp/az-08-01` termina en `0 issue(s)`.
- Ningún entregable contiene GUIDs reales de tenant/suscripción.
- Un ingeniero externo puede leer `otel-walkthrough.md` y aplicar los pasos.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Correctitud sintáctica**: JSON válido, KQL razonable.
- **Correctitud conceptual** (autoevaluación): comparar con `solution/REFERENCE.md`.
- **Seguridad del repo**: nada parecido a credenciales ni IDs reales.

## 8. Validación

```bash
bash tests/validate.sh /tmp/az-08-01
```

El validador comprueba sintaxis y presencia de claves/menciones mínimas; **no** valida que la alerta, aplicada a un workspace real, dispare como esperas. Esa prueba se hace en Fase 4.

## 9. Preguntas de reflexión

1. ¿Por qué `connection string` reemplazó al `instrumentation key`? ¿Qué información lleva de más?
2. Si pones `evaluationFrequency: PT1M` sobre un `AppRequests` de 500 GB/día, ¿qué pasa con la factura?
3. ¿Cuándo preferirías un **Activity Log Alert** sobre una **Scheduled Query Rule** para el mismo caso?
4. ¿Qué cambia si en vez de direct exporter usas un **OTel Collector** sidecar?
5. ¿Cómo detectas si tu instrumentación OTel está perdiendo spans por sampling?

## 10. Extensiones

- Añade un segundo alert JSON (`alert-high-latency.json`) basado en `percentile(DurationMs, 95)`.
- Añade una query de **cost audit** sobre `Usage` que muestre top-10 tablas por GB.
- Convierte `app-insights-alert.json` a Terraform `azurerm_monitor_scheduled_query_rules_alert_v2` como ejercicio extra.

## 11. Limpieza

```bash
rm -rf /tmp/az-08-01
```

No hay infraestructura que detener.
