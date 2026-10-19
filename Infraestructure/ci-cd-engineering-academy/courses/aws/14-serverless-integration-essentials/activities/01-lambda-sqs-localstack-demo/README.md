# Actividad 01 — Demo Lambda + SQS en LocalStack

## 1. Identificación

- **ID:** `aws-14-01-lambda-sqs-localstack-demo`
- **Tecnología:** `aws`
- **Módulo:** `aws-14-serverless-integration-essentials`
- **Dificultad:** advanced
- **Duración estimada:** 45–60 min
- **Tipo:** demo (sin dependencia de la actividad 02)

## 2. Contexto

Vamos a ejecutar un flujo canónico serverless — **cola SQS → trigger → Lambda que procesa el mensaje** — **sin tocar una cuenta AWS real**. El entorno es [LocalStack](https://localstack.cloud/) corriendo en Docker. El objetivo no es dominar LocalStack ni Terraform; es que **toques con las manos** el ciclo "envío un mensaje, el handler se ejecuta, veo el log" para que las ideas de la lección dejen de ser abstractas.

**Coste**: cero euros. Todo es local.

**Degradación limpia**: si no tienes Docker o no tienes LocalStack, el validador imprime `SKIP: localstack not available` y termina en verde. Puedes seguir leyendo el handler y la referencia; no estás obligado a instalar nada.

## 3. Objetivos

Al terminar deberías poder:

- Levantar LocalStack con `docker run` y confirmar su salud (`/_localstack/health`).
- Crear una cola SQS y una función Lambda vía `awslocal` (wrapper CLI con endpoints apuntando a LocalStack) **o** vía `aws` CLI con `--endpoint-url`.
- Vincular SQS → Lambda como event source mapping.
- Enviar un mensaje y comprobar que el handler se ejecutó inspeccionando logs.
- Entender por qué este flujo **con los mismos comandos sin `--endpoint-url`** valdría contra AWS real (y por qué nunca lo harías así sin un presupuesto y alertas antes).

## 4. Prerrequisitos

- **Docker** instalado y running (`docker ps` sin error).
- (Opcional pero recomendado) `awscli` v2 instalado. No se necesitan credenciales reales — usaremos `aws configure set` con valores dummy.
- Python 3.9+ (solo para empaquetar el `handler.py` en un zip; no se ejecuta localmente).

Nada de todo lo anterior se descarga automáticamente. Si falta, el validador salta.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-14-lambda-sqs
cd /tmp/aws-14-lambda-sqs
```

### 5.2 (Si tienes Docker) Levantar LocalStack

```bash
docker run --rm -d \
  --name aws-14-localstack \
  -p 4566:4566 \
  -e SERVICES=lambda,sqs,logs,iam \
  -e DEBUG=0 \
  localstack/localstack:latest

# Esperar a que esté sano
until curl -fs http://localhost:4566/_localstack/health >/dev/null; do
  sleep 2
done
```

### 5.3 Configurar `aws` CLI con credenciales dummy

LocalStack ignora las credenciales pero el CLI exige que haya **alguna**:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export ENDPOINT="--endpoint-url=http://localhost:4566"
```

### 5.4 Crear la cola SQS

```bash
aws $ENDPOINT sqs create-queue --queue-name orders
QUEUE_URL=$(aws $ENDPOINT sqs get-queue-url --queue-name orders --query QueueUrl --output text)
QUEUE_ARN=$(aws $ENDPOINT sqs get-queue-attributes --queue-url "$QUEUE_URL" \
  --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)
echo "Queue: $QUEUE_URL"
echo "ARN:   $QUEUE_ARN"
```

### 5.5 Empaquetar el handler

Copia `starter/handler.py` a `/tmp/aws-14-lambda-sqs/handler.py` (o escribe el tuyo) y empaqueta:

```bash
cp <ruta-repo>/courses/aws/14-serverless-integration-essentials/activities/01-lambda-sqs-localstack-demo/starter/handler.py .
zip -q function.zip handler.py
```

### 5.6 Crear un role (dummy) y la Lambda

```bash
aws $ENDPOINT iam create-role \
  --role-name aws-14-lambda-role \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
  >/dev/null

aws $ENDPOINT lambda create-function \
  --function-name orders-worker \
  --runtime python3.11 \
  --role arn:aws:iam::000000000000:role/aws-14-lambda-role \
  --handler handler.lambda_handler \
  --zip-file fileb://function.zip \
  >/dev/null
```

### 5.7 Vincular SQS → Lambda

```bash
aws $ENDPOINT lambda create-event-source-mapping \
  --function-name orders-worker \
  --event-source-arn "$QUEUE_ARN" \
  --batch-size 1 \
  >/dev/null
```

### 5.8 Enviar un mensaje y comprobar

```bash
aws $ENDPOINT sqs send-message \
  --queue-url "$QUEUE_URL" \
  --message-body '{"order_id":"42","amount":99.90}'

# Dar un par de segundos al event source polling
sleep 5

# Buscar la línea JSON del handler en los logs
aws $ENDPOINT logs describe-log-groups --query 'logGroups[].logGroupName'
aws $ENDPOINT logs tail /aws/lambda/orders-worker --since 1m || true
```

Deberías ver algo como:

```
INFO {"msg": "handler.invoked", "service": "orders-worker", ...}
INFO {"msg": "handler.done", "request_id": "...", "count": 1}
```

### 5.9 Limpieza

```bash
docker stop aws-14-localstack >/dev/null 2>&1 || true
rm -rf /tmp/aws-14-lambda-sqs
```

## 6. Validación

```bash
bash tests/validate.sh /tmp/aws-14-lambda-sqs
```

El validador:

1. Comprueba que el directorio existe y contiene `handler.py`.
2. Verifica el handler **estructuralmente** (define `lambda_handler`, no usa `print`, logging estructurado, etc.) — esto se chequea **siempre**, incluso sin LocalStack.
3. Si **hay** Docker y LocalStack running en `localhost:4566`, verifica que la cola `orders` y la Lambda `orders-worker` existen. Si **no**, imprime `SKIP: localstack not available` y pasa.

## 7. Resultado esperado

- Validador en verde (todo OK, o SKIP limpio donde aplique).
- Un `handler.py` en `/tmp/aws-14-lambda-sqs` listo.
- (Si corriste la demo) un mensaje procesado y visible en los logs de la Lambda.

## 8. Preguntas de reflexión

1. En LocalStack el `event source mapping` dispara la Lambda con el mismo shape que SQS real envía. Mira el `event` que llega al handler: ¿qué campos vienen y para qué sirve cada uno?
2. ¿Qué cambiaría en los comandos para apuntar a AWS **real** en vez de LocalStack? ¿Y qué deberías asegurarte antes de hacerlo (presupuesto, roles, región)?
3. Si subes `--batch-size` a 10 y envías 10 mensajes de golpe, ¿cuántos invokes esperas? ¿Cuántos logs?
4. ¿Qué dos cosas pasarían si borrases el `event source mapping` y luego enviases un mensaje a la cola?

## 9. Extensiones

- Añade **DLQ**: crea una segunda cola `orders-dlq`, configura `RedrivePolicy` sobre `orders` con `maxReceiveCount=2`, haz que el handler lance excepción si `order_id` empieza por `fail-` y confirma que el mensaje acaba en la DLQ.
- Mide latencia: añade `time.perf_counter()` fuera y dentro del handler para separar cold start de invoke.
- Reemplaza el `handler.py` por una versión con `aws-lambda-powertools` (requiere empaquetarlo en el zip o usar una Lambda layer).

## 10. Limpieza

```bash
docker stop aws-14-localstack >/dev/null 2>&1 || true
rm -rf /tmp/aws-14-lambda-sqs
```

Si LocalStack quedó corriendo de una sesión previa, siempre puedes `docker ps -a | grep localstack` para encontrarla.
