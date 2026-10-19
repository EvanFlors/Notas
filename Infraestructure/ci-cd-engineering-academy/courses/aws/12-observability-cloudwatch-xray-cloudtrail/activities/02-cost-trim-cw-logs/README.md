# Actividad 02 — Recorte de coste CloudWatch Logs (plan de retención + metric filter + Insights + alarma)

## 1. Identificación

- **ID:** `aws-12-02-cost-trim-cw-logs`
- **Tecnología:** `aws`
- **Módulo:** `aws-12-observability-cloudwatch-xray-cloudtrail`
- **Dificultad:** advanced
- **Duración estimada:** 50–60 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Tu plataforma gasta **4 500 USD/mes** solo en CloudWatch Logs. Un análisis preliminar muestra:

- 60 % del gasto viene de `/aws/lambda/*` con nivel `DEBUG` en producción.
- 20 % de access logs ALB con retención `never-expire`.
- 20 % de audit logs reales (CloudTrail, VPC Flow Logs) que **no** se pueden tocar.

Te piden un **plan de recorte** que no apague señal útil y, de paso, un **metric filter**, una **query Logs Insights** y una **alarma CloudWatch** que materialicen el nuevo régimen. La actividad es puramente de artefactos de configuración y análisis — **no se despliega nada en AWS**.

## 3. Objetivos

Al terminar deberías:

- Articular un plan de **retention por tier** con días concretos y justificación.
- Escribir un `metric_filter.json` con `filterPattern` y `metricTransformations` válidos.
- Escribir una query **Logs Insights** acotada en tiempo y campos.
- Escribir una **alarma CloudWatch** JSON (static o composite) con `TreatMissingData` justificado.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§2, §3, §4, §5, §10).
- Haber recorrido `../../examples/01-cloudwatch-logs-insights/`.
- Herramientas: `bash`, editor Markdown/JSON. `python3` con `json` (stdlib) para la validación.

**Costos:** cero. Todo es texto.

## 5. Instrucciones

### 5.1 Preparar directorio

```bash
mkdir -p /tmp/aws-12-cost
cd /tmp/aws-12-cost
```

### 5.2 Produce 4 ficheros

#### 5.2.1 `RETENTION.md`

Markdown con **al menos** una tabla con 3 filas (hot/warm/cold), y **3 bullets numerados** justificando trade-offs. Debe mencionar `retention_in_days` como término técnico.

Ejemplo de forma (adáptalo):

```
## Plan de retención

| Tier | retention_in_days | Log groups ejemplo | Justificación |
|------|-------------------|---------------------|---------------|
| hot  | 7   | /aws/lambda/* (DEBUG) | ...          |
| warm | 30  | /aws/app/*            | ...          |
| cold | 400 | /aws/cloudtrail/*     | ...          |

## Trade-offs

1. ...
2. ...
3. ...
```

#### 5.2.2 `metric_filter.json`

JSON válido con `filterPattern` + `metricTransformations`. Ejemplo mental:

```json
{
  "logGroupName": "/aws/app/fastapi",
  "filterName": "CountFive hundred Errors",
  "filterPattern": "{ $.level = \"ERROR\" && $.status >= 500 }",
  "metricTransformations": [
    {
      "metricName": "AppErrorCount5xx",
      "metricNamespace": "App/FastAPI",
      "metricValue": "1",
      "defaultValue": 0,
      "unit": "Count"
    }
  ]
}
```

Debe parsear como JSON y contener las claves listadas.

#### 5.2.3 `insights.md`

Markdown que incluya **una** query Logs Insights en un bloque de código. Debe:

- Usar al menos `fields`, `filter` y `stats`.
- Acotar explícitamente el tiempo (`bin()` o un comentario de range).

#### 5.2.4 `alarm.json`

JSON válido con la estructura de un `PutMetricAlarm` o composite. Campos mínimos:

- `AlarmName`
- `MetricName` o `AlarmRule` (para composite)
- `ComparisonOperator`
- `EvaluationPeriods`
- `DatapointsToAlarm`
- `Threshold` (si es static)
- `TreatMissingData` **justificado** (al menos en un comentario del JSON no, pero en `RETENTION.md` menciónalo).

### 5.3 Valida

```bash
bash tests/validate.sh /tmp/aws-12-cost
```

## 6. Resultado esperado

- Los 4 ficheros existen y validan estructuralmente.
- `RETENTION.md` menciona hot/warm/cold y `retention_in_days`.
- `metric_filter.json` parsea y tiene `filterPattern` + `metricTransformations[0].metricName`.
- `insights.md` contiene una query con `fields`, `filter` y `stats`.
- `alarm.json` parsea y tiene `AlarmName`, `EvaluationPeriods`, `DatapointsToAlarm`, `TreatMissingData`.

## 7. Criterios de aceptación

- **Funcionalidad:** validador estructural pasa.
- **Calidad:** los días de retención están justificados (no son 1 ni never-expire sin razón).
- **Economía:** el plan reduce el gasto estimado — explica cuántos % de forma cualitativa.
- **Seguridad:** no incluir account IDs ni ARNs reales (usar `123456789012` como placeholder si hace falta).

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-12-cost
```

## 9. Preguntas de reflexión

1. ¿Por qué `TreatMissingData=missing` puede ser **peligroso** en una alarma de salud?
2. ¿Qué pasaría con tu plan si los access logs ALB se multiplican por 10 (nueva campaña de marketing)?
3. ¿Qué parte del gasto no puedes recortar y por qué está justificado mantenerla?
4. Si en vez de un metric filter sacas la métrica con **EMF** desde la app, ¿qué cambia en coste y en cardinalidad?
5. ¿En qué momento la query Logs Insights se vuelve más cara que exportar los logs a Loki y pagar storage allí?

## 10. Extensiones

- Añade una **composite alarm** que solo dispare si "errores 5xx altos **Y** latencia p95 alta".
- Añade una **subscription filter** JSON que exporte a Kinesis Firehose → S3 para los logs que decides sacar de CloudWatch.
- Calcula un ahorro aproximado en USD usando el precio actual (consulta `../../resources/links.md`).

## 11. Limpieza

```bash
rm -rf /tmp/aws-12-cost
```
