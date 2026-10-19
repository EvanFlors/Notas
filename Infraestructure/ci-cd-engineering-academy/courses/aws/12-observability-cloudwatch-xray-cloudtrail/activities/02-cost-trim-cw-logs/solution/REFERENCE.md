# REFERENCE — aws-12-02-cost-trim-cw-logs

> Modelo razonado. No es la única respuesta correcta.

## RETENTION.md (modelo)

```markdown
## Plan de retención

| Tier | retention_in_days | Log groups ejemplo               | Justificación |
|------|-------------------|----------------------------------|---------------|
| hot  | 7                 | /aws/lambda/*  (prod a INFO)     | Debug reciente; a los 7 días pierde valor operativo. |
| warm | 30                | /aws/app/fastapi, ALB access     | Ventana de SRE para post-mortems; cubre un sprint. |
| cold | 400               | /aws/cloudtrail/*, VPC Flow      | Requisito de compliance (anual + buffer); never-expire NO. |

## Trade-offs

1. Pasar `/aws/lambda/*` de nivel DEBUG a INFO en prod recorta ~60 % del volumen; DEBUG queda sólo en dev/stg.
2. Access logs ALB migran de never-expire a 30 días. Lo que necesite más tiempo se exporta a S3 con lifecycle a Glacier (storage es ~20× más barato que CloudWatch Logs).
3. Alarma con `TreatMissingData=breaching` sobre `AppErrorCount5xx` — si deja de llegar, es más probable que la app no esté loggeando que que esté perfecta.
```

## metric_filter.json (modelo)

```json
{
  "logGroupName": "/aws/app/fastapi",
  "filterName": "App5xxErrors",
  "filterPattern": "{ $.level = \"ERROR\" && $.status >= 500 }",
  "metricTransformations": [
    {
      "metricName": "AppErrorCount5xx",
      "metricNamespace": "App/FastAPI",
      "metricValue": "1",
      "defaultValue": 0,
      "unit": "Count",
      "dimensions": {
        "Service": "$.service",
        "Env": "$.env"
      }
    }
  ]
}
```

Nota: el `filterPattern` asume logs JSON. Si fueran logs plano:
```
[level=ERROR, status=5*]
```

## insights.md (modelo)

```markdown
## Logs Insights — 5xx por minuto (último hour)

Rango: últimas 60 minutos.

\`\`\`
fields @timestamp, @message, status, service
| filter level = "ERROR" and status >= 500
| stats count() as errors by bin(1m), service
| sort @timestamp desc
| limit 120
\`\`\`

Decisiones:

- `filter` antes de `stats` para no escanear bytes de más.
- `bin(1m)` para granularidad fina en una hora.
- `limit 120` acota la respuesta sin truncar la ventana temporal.
```

## alarm.json (modelo static)

```json
{
  "AlarmName": "App-5xx-High",
  "AlarmDescription": "Dispara si AppErrorCount5xx > 10 en 2 de 3 datapoints de 1 minuto.",
  "ActionsEnabled": true,
  "AlarmActions": ["arn:aws:sns:us-east-1:123456789012:oncall-platform"],
  "MetricName": "AppErrorCount5xx",
  "Namespace": "App/FastAPI",
  "Statistic": "Sum",
  "Period": 60,
  "EvaluationPeriods": 3,
  "DatapointsToAlarm": 2,
  "Threshold": 10,
  "ComparisonOperator": "GreaterThanThreshold",
  "TreatMissingData": "breaching"
}
```

Alternativa composite (si quieres combinar con latencia):

```json
{
  "AlarmName": "App-5xx-AND-p95-High",
  "AlarmRule": "ALARM(App-5xx-High) AND ALARM(App-p95-High)",
  "ActionsEnabled": true,
  "AlarmActions": ["arn:aws:sns:us-east-1:123456789012:oncall-platform"]
}
```

## Punto a repetir

> La economía de CloudWatch Logs se decide **antes** de ingerir. Filtra en la app o en el Collector, retén por tier, y usa metric filters + Insights como herramienta de investigación, no como dashboard permanente.
