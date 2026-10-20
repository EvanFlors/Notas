# Starter — aws-14-02-event-driven-design-decisions

Actividad **independiente**: no hay código ni plantilla que ejecutar. Tu entregable son dos archivos Markdown/JSON escritos por ti.

## Pasos

1. Lee `../README.md` completo, especialmente el escenario de §2.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/aws-14-design
   cd /tmp/aws-14-design
   ```
3. Crea `DECISIONS.md` con las 5 secciones (A: compute, B: topología, C: FIFO vs Standard, D: costos ocultos, E: nota sobre la ASL).
4. Crea `pdf-report.asl.json` con una Step Function mínima (ver §5.2.E del README y la plantilla sugerida más abajo).
5. Valida:
   ```bash
   bash <ruta-repo>/courses/aws/14-serverless-integration-essentials/activities/02-event-driven-design-decisions/tests/validate.sh /tmp/aws-14-design
   ```
6. Compara con `../solution/REFERENCE.md`.

## Plantilla sugerida de `pdf-report.asl.json`

Puedes partir de esta plantilla y adaptarla; el validador solo exige que sea JSON válido, tenga `StartAt` y los campos clave:

```json
{
  "Comment": "Batch PDF diario — placeholder; adaptar segun tu diseno",
  "StartAt": "ListarFotosDelDia",
  "States": {
    "ListarFotosDelDia": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "arn:aws:lambda:us-east-1:123456789012:function:ListarFotos",
        "Payload.$": "$"
      },
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2.0
        }
      ],
      "Next": "HayFotos"
    },
    "HayFotos": {
      "Type": "Choice",
      "Choices": [
        { "Variable": "$.count", "NumericGreaterThan": 0, "Next": "GenerarPDF" }
      ],
      "Default": "SinDatos"
    },
    "GenerarPDF": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "arn:aws:lambda:us-east-1:123456789012:function:GenerarPDF",
        "Payload.$": "$"
      },
      "End": true
    },
    "SinDatos": {
      "Type": "Pass",
      "End": true
    }
  }
}
```

> El validador JSON solo exige que **tus** `Next` apunten a estados definidos y que el documento sea JSON válido. Es responsabilidad tuya que la lógica tenga sentido para el batch PDF que diseñaste.
