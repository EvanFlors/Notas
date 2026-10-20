# Actividad 01 — SLO + alerting policy JSON + logs-based metric

## 1. Identificación

- **ID:** `gcp-08-01-slo-and-alerting-policy-json`
- **Tecnología:** `gcp`
- **Módulo:** `gcp-08-observability-cloud-ops-audit-logs`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** architecture (independent — sin dependencia de la actividad 02)

## 2. Contexto

El servicio **`checkout-api`** vive en **Cloud Run** y es la ruta crítica de pago. SLA interno: **99.9% de disponibilidad en 30 días**. La definición operativa de "disponible" es: `request_count` con `response_code_class != 5xx`.

El equipo observabilidad quiere:

1. Un **SLO** declarativo sobre el service para medirlo igual que el SRE book.
2. Una **alerting policy** con **burn rate alert** que avise en Slack cuando el budget se consume rápido.
3. Una **log-based metric** (counter) que extraiga eventos `payment_declined` del log de la app para dashboard de negocio.
4. Un **ADR** que registre las decisiones y 2 alternativas descartadas.
5. Un **README-INTENT.md** que explique a un ingeniero nuevo qué hace cada pieza y cómo encajan.

**Importante**: no hay project GCP real. No se provisiona nada. El entregable es un conjunto de **documentos y JSONs validados estructuralmente**. Usa siempre el placeholder `PROJECT_ID` donde iría un project real.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Explicar la diferencia entre SLI, SLO y error budget con un ejemplo.
- Escribir una `alerting-policy.json` que Cloud Monitoring aceptaría estructuralmente.
- Escribir una `logs-based-metric.json` que Cloud Logging aceptaría estructuralmente.
- Decidir y defender un **rolling period** para el SLO (30 días vs 7 días).
- Argumentar por qué **burn rate alerts** son mejores que "alertar cada 5xx".

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §4 Monitoring/SLOs, §3 logs y log-based metrics, §10 SLI/SLO/error budget).
- Haber recorrido el `examples/01-otel-to-cloud-trace-adot/`.
- Haber completado `gcp-04` (Cloud Run) y `gcp-07` (GKE).
- Herramientas: `bash`, `jq`, un editor Markdown. **No** se necesita cuenta GCP.

**Costos**: ninguno. Todo es local.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/gcp-08-slo
cd /tmp/gcp-08-slo
```

Puedes usar otro directorio: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `alerting-policy.json`

Un JSON válido con:

- `displayName` descriptivo (incluye el nombre del servicio).
- `combiner` (`AND` u `OR`).
- `conditions`: array con al menos un elemento con `conditionThreshold` (o `conditionMatchedLog`, `conditionAbsent` según corresponda) que apunte a una métrica `run.googleapis.com/...` o a un SLO burn rate.
- `notificationChannels`: array con al menos un canal (puede ser placeholder `projects/PROJECT_ID/notificationChannels/CHANNEL_ID`).
- `documentation.content`: markdown con runbook, dashboard URL (placeholder) y owner. **Obligatorio**.
- `alertStrategy.autoClose`: duración en segundos (p. ej. `"1800s"`).

### 5.3 Escribe `logs-based-metric.json`

Un JSON válido con:

- `name` (identificador).
- `description`.
- `filter`: filtro de Cloud Logging (p. ej. `resource.type="cloud_run_revision" AND jsonPayload.event="payment_declined"`).
- `metricDescriptor.metricKind`: `DELTA` (counter) o `CUMULATIVE`.
- `metricDescriptor.valueType`: `INT64` para counter, `DISTRIBUTION` para distribution.
- `labelExtractors`: diccionario con al menos un extractor (p. ej. `{"reason": "EXTRACT(jsonPayload.reason)"}`).

### 5.4 Escribe `SLO-ADR.md`

Secciones obligatorias (el validador las busca):

1. `# ADR` ... en el encabezado.
2. `## Estado` (o `Status`).
3. `## Contexto` (o `Context`).
4. `## Decisión` (o `Decision`).
5. `## Consecuencias` (o `Consequences`).
6. `## Alternativas` (o `Alternatives`) — al menos 2 descartadas.

Debe mencionar: `SLI`, `SLO`, `error budget` o `burn rate`, el goal numérico (`99.9`), `Cloud Run`, `checkout`, y una ventana rolling (30 días o 7 días).

### 5.5 Escribe `README-INTENT.md`

Un documento corto que, por cada entregable, explique:

- `## alerting-policy` — qué métrica mira, qué threshold, por qué.
- `## logs-based-metric` — qué patrón de log extrae y qué label captura.
- `## SLO` — qué SLI usa, qué goal, qué rolling period.

Debe mencionar explícitamente `burn rate`, `notificationChannels` y `documentation` (justifica por qué el runbook es obligatorio).

### 5.6 Entregables

```
/tmp/gcp-08-slo/alerting-policy.json
/tmp/gcp-08-slo/logs-based-metric.json
/tmp/gcp-08-slo/SLO-ADR.md
/tmp/gcp-08-slo/README-INTENT.md
```

## 6. Resultado esperado

- Los 4 archivos existen y pasan el validador estructural.
- No usas project IDs reales. Siempre `PROJECT_ID`, `CHANNEL_ID`, `SERVICE_ID` como placeholders.
- Un ingeniero puede leer el ADR + README-INTENT y entender exactamente qué se materializaría en Fase 4 con Terraform.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa (`0 issue(s)`).
- **Calidad**: cada decisión está justificada, no solo listada.
- **Reproducibilidad**: alguien podría tomar los JSON y aplicarlos con `gcloud alpha monitoring policies create --policy-from-file=alerting-policy.json` tras sustituir placeholders.
- **Mantenibilidad**: JSON pretty-printed, Markdown válido.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gcp-08-slo
```

El validador comprueba **estructura**, no semántica. Compara después con `solution/REFERENCE.md`.

## 9. Preguntas de reflexión

1. ¿Por qué un burn rate alert (fast burn 2% / 1h) es preferible a "alerta si 5xx rate > 1% durante 5 min"?
2. Si tu SLO fuera 99.99%, ¿cambiarías el rolling period? ¿Por qué?
3. ¿Qué pasa si la `logs-based-metric` tiene un `filter` tan amplio que matchea millones de logs/día? ¿Costo? ¿Cardinality?
4. ¿Dónde pondrías el canal de notificación distinto para P1 (PagerDuty) vs P2 (Slack)? ¿Lo haces en una sola policy o en dos?
5. Si en producción el runbook del `documentation.content` apunta a una página que ya no existe, ¿cómo lo detectas antes del siguiente incidente?

## 10. Extensiones

- Añadir una segunda `alerting-policy-slow-burn.json` para 10% de budget en 3 días (P2).
- Añadir un `dashboard.json` que agrupe la métrica custom + request count + latency.
- Modelar un **log-based metric distribution** sobre latencia extraída del log.

## 11. Limpieza

```bash
rm -rf /tmp/gcp-08-slo
```

No hay procesos ni infra que detener.
