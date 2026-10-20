# REFERENCE — aws-14-01-lambda-sqs-localstack-demo

> Modelo de solución. No es la única secuencia válida; es una contra la que compararte.

## Flujo end-to-end comentado

```bash
# 0. Variables de entorno (dummy — LocalStack las ignora, pero el CLI las exige).
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export ENDPOINT="--endpoint-url=http://localhost:4566"
export BASE=/tmp/aws-14-lambda-sqs
mkdir -p "$BASE" && cd "$BASE"

# 1. Levantar LocalStack sin volúmenes (contenedor efímero).
docker run --rm -d \
  --name aws-14-localstack \
  -p 4566:4566 \
  -e SERVICES=lambda,sqs,logs,iam \
  localstack/localstack:latest

until curl -fs http://localhost:4566/_localstack/health >/dev/null; do sleep 2; done

# 2. Empaquetar handler.
cp <ruta-repo>/.../starter/handler.py .
zip -q function.zip handler.py

# 3. Role dummy (LocalStack no evalúa el trust policy — solo necesita que exista).
aws $ENDPOINT iam create-role \
  --role-name aws-14-lambda-role \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

# 4. SQS.
aws $ENDPOINT sqs create-queue --queue-name orders
QUEUE_URL=$(aws $ENDPOINT sqs get-queue-url --queue-name orders --query QueueUrl --output text)
QUEUE_ARN=$(aws $ENDPOINT sqs get-queue-attributes --queue-url "$QUEUE_URL" \
  --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)

# 5. Lambda.
aws $ENDPOINT lambda create-function \
  --function-name orders-worker \
  --runtime python3.11 \
  --role arn:aws:iam::000000000000:role/aws-14-lambda-role \
  --handler handler.lambda_handler \
  --zip-file fileb://function.zip

# 6. Event source mapping (SQS -> Lambda).
aws $ENDPOINT lambda create-event-source-mapping \
  --function-name orders-worker \
  --event-source-arn "$QUEUE_ARN" \
  --batch-size 1

# 7. Enviar un mensaje y leer logs.
aws $ENDPOINT sqs send-message \
  --queue-url "$QUEUE_URL" \
  --message-body '{"order_id":"42","amount":99.90}'

sleep 5

aws $ENDPOINT logs tail /aws/lambda/orders-worker --since 2m
```

## Qué deberías observar en los logs

Dos líneas JSON por invocación:

```
INFO {"msg": "handler.invoked", "service": "orders-worker", "env": "local", "request_id": "..."}
INFO {"msg": "handler.done", "request_id": "...", "count": 1}
```

Si envías un mensaje malformado (sin `order_id` o con body no-JSON):

```
INFO {"msg": "handler.invoked", "service": "orders-worker", ...}
ERROR {"msg": "handler.invalid_event", "request_id": "...", "error": "payload missing order_id"}
```

En SQS real, ese mensaje volvería a aparecer tras `VisibilityTimeout`, se reentregaría hasta `maxReceiveCount` y acabaría en la DLQ. LocalStack hace lo mismo si configuras `RedrivePolicy`.

## Si LocalStack **no** está disponible

El validador salta la verificación de infra con `SKIP: localstack not available` y comprueba **solo** la estructura del `handler.py` (definición de `lambda_handler`, logging estructurado, no uso de `print`). Es un `OK` legítimo — la demo es ejecutable para quien tenga Docker; el resto se queda con el análisis del handler.

## Errores comunes

- **`InvalidClientTokenId`**: olvidaste `AWS_ACCESS_KEY_ID=test`.
- **`Could not connect to the endpoint URL`**: LocalStack no está corriendo o `$ENDPOINT` apunta a otro puerto.
- **Lambda nunca se invoca**: `create-event-source-mapping` quedó en estado `Creating` eternamente — en LocalStack a veces hay que esperar unos segundos tras crearlo; con `--batch-size 1` suele ser instantáneo. Verifica también que el ARN de la cola es correcto.
- **`Role is required`**: LocalStack sí exige el role (aunque no lo evalúe); crea el role dummy del paso 3.

## Puente conceptual a AWS real

Los **mismos** comandos sin `--endpoint-url` crean los **mismos** recursos en AWS real. La única diferencia relevante:

- IAM evaluará **de verdad** el role (necesitas `AWSLambdaBasicExecutionRole` adjunto para que la Lambda escriba logs).
- SQS, Lambda y CloudWatch Logs **cobrarán** (en Free Tier casi todo cabe para esta demo, pero no asumas que es gratis en escala).
- Antes de hacerlo contra AWS real: `aws-01` presupuesto + alerta. Siempre.
