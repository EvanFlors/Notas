# Ejemplo 01 — Anatomía de un handler Lambda (Python)

> Lectura y análisis. Objetivo: fijar en memoria **qué va fuera del handler**, **qué va dentro** y **qué piezas** separan un handler "didáctico" de uno que no pierde ni duplica mensajes en producción.

## 1. El handler mínimo que todos conocen

```python
def lambda_handler(event, context):
    print("hola")
    return {"statusCode": 200, "body": "ok"}
```

Esto corre y no fallaría ninguna demo. Y es exactamente lo que **no** debes imitar para integraciones reales.

## 2. El handler que sí deberías escribir

```python
# handler.py
# --- fuera del handler: una vez por instancia ---
import json
import logging
import os
import uuid

LOG = logging.getLogger()
LOG.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# Clientes AWS (si los hubiera) van AQUI, no dentro del handler.
# Ejemplo (comentado para que el handler sea autosuficiente):
#     import boto3
#     DDB = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

ENV = os.environ.get("ENVIRONMENT", "dev")
SERVICE = os.environ.get("SERVICE_NAME", "orders-worker")


class InvalidEvent(ValueError):
    """Raised when the incoming event is malformed."""


def _validate(event: dict) -> dict:
    """Extract the fields we care about or raise InvalidEvent."""
    if not isinstance(event, dict):
        raise InvalidEvent(f"event is not a dict: {type(event).__name__}")

    # Example: SQS event with Records[]
    records = event.get("Records")
    if not records:
        raise InvalidEvent("missing Records")

    out = []
    for rec in records:
        body = rec.get("body")
        if body is None:
            raise InvalidEvent("record missing body")
        try:
            payload = json.loads(body)
        except json.JSONDecodeError as exc:
            raise InvalidEvent(f"body is not valid JSON: {exc}") from exc
        if "order_id" not in payload:
            raise InvalidEvent("payload missing order_id")
        out.append(payload)
    return {"orders": out}


def _process_one(order: dict, request_id: str) -> dict:
    """Idempotent business logic. Keyed by order_id."""
    # In a real system: DDB.put_item(..., ConditionExpression="attribute_not_exists(order_id)")
    # Here we just simulate.
    return {"order_id": order["order_id"], "status": "processed",
            "request_id": request_id}


def lambda_handler(event, context):
    # Correlation id: use AWS request id if available, else generate.
    request_id = getattr(context, "aws_request_id", None) or str(uuid.uuid4())

    LOG.info(json.dumps({
        "msg": "handler.invoked",
        "service": SERVICE,
        "env": ENV,
        "request_id": request_id,
    }))

    try:
        validated = _validate(event)
    except InvalidEvent as exc:
        LOG.error(json.dumps({
            "msg": "handler.invalid_event",
            "request_id": request_id,
            "error": str(exc),
        }))
        # For SQS-triggered Lambdas, re-raising sends the message to retry/DLQ.
        # For API Gateway, return a 4xx. Pick based on the invoker.
        raise

    results = []
    for order in validated["orders"]:
        try:
            results.append(_process_one(order, request_id))
        except Exception as exc:  # noqa: BLE001 — top-level barrier
            LOG.exception(json.dumps({
                "msg": "handler.process_failed",
                "request_id": request_id,
                "order_id": order.get("order_id"),
                "error": str(exc),
            }))
            # Decide: raise to retry whole batch, or report partial batch
            # failure via "batchItemFailures" (SQS specific).
            raise

    LOG.info(json.dumps({
        "msg": "handler.done",
        "request_id": request_id,
        "count": len(results),
    }))
    return {"processed": len(results), "request_id": request_id}
```

## 3. Qué cambia respecto al handler ingenuo (y por qué)

### 3.1 "Fuera del handler" vs "dentro"

- `LOG`, imports, clientes AWS, lecturas de env: **arriba**. Se ejecutan **una vez por instancia** (cold start). Reutilizar la misma `boto3.resource` entre invocaciones ahorra TLS handshakes y conexiones.
- La lógica concreta de **esta** invocación: **dentro** del handler. Dentro del handler **nunca** se instancia un cliente AWS — se referencia el global.

### 3.2 Validación explícita de evento

- Nunca asumir shape del evento. SQS, EventBridge, API Gateway, S3 tienen formas **distintas**. Validarlo con una función dedicada hace que un evento malformado produzca un error claro en logs, no un `KeyError` oscuro.
- `InvalidEvent` como excepción custom permite distinguir "el evento es basura" (no reintentar: siempre va a fallar) de "fallo transitorio" (reintentar).

### 3.3 `request_id` como clave de correlación

- Usar `context.aws_request_id` (que CloudWatch, X-Ray y SQS ya conocen) permite correlacionar logs, traces y eventos sin inventar nada.
- Si `context` no está (tests unitarios, ejecución local), `uuid.uuid4()` cubre el hueco sin que la lógica cambie.

### 3.4 Logging estructurado JSON

- `json.dumps({...})` emite líneas que CloudWatch Logs Insights (y cualquier backend serio) parsea sin regex. **No** uses f-strings con texto libre para datos operativos.
- Nivel configurable por env var (`LOG_LEVEL`) para poder subir a `DEBUG` en incidentes y bajar sin redeployar.

### 3.5 Idempotencia explícita (comentada aquí, obligatoria en real)

- `_process_one` usa `order_id` como clave. En un sistema real sería un `ConditionExpression="attribute_not_exists(order_id)"` o un `@idempotent` de Powertools.
- Sin esto, un retry (SQS at-least-once) duplica el procesamiento. **Es un bug esperando a producción**.

### 3.6 Error handling diferenciado por tipo

- `InvalidEvent` → **error terminal** del mensaje (en SQS, con `maxReceiveCount` bajo o con una regla específica, va a la DLQ pronto).
- Cualquier otra `Exception` → **retry** (la Lambda falla, SQS reentregará; si supera `maxReceiveCount`, va a la DLQ).
- La diferencia la hace **el invoker**: SQS reintentará; API Gateway no (devolvería 5xx al cliente). Diseñar sabiendo quién llama.

## 4. Lo mismo con `aws-lambda-powertools` (vista rápida)

Si tu stack adopta Powertools, el handler se queda así:

```python
from aws_lambda_powertools import Logger, Tracer, Metrics
from aws_lambda_powertools.utilities.data_classes import SQSEvent, event_source
from aws_lambda_powertools.utilities.idempotency import idempotent_function, DynamoDBPersistenceLayer

logger = Logger()
tracer = Tracer()
metrics = Metrics()
persistence = DynamoDBPersistenceLayer(table_name="idempotency-store")

@idempotent_function(data_keyword_argument="order", persistence_store=persistence)
def _process_one(order: dict) -> dict:
    return {"order_id": order["order_id"], "status": "processed"}

@event_source(data_class=SQSEvent)
@logger.inject_lambda_context
@tracer.capture_lambda_handler
@metrics.log_metrics
def lambda_handler(event: SQSEvent, context):
    for record in event.records:
        _process_one(order=record.json_body)
    return {"ok": True}
```

Decorators resuelven: logging estructurado con contexto, tracing X-Ray/OTel, métricas EMF, idempotencia contra DynamoDB. Es opcional pero **recomendado** si vas a escribir > 3 Lambdas en el mismo proyecto.

## 5. Lo que NO debería estar en tu handler

- **Reintentos manuales con `sleep`** — reinicia la invocación entera, mejor dejar el retry al invoker (SQS, Step Functions).
- **Loops largos** — si procesas 10K items, usa Step Functions `Map` o SQS batch, no un for de 10K dentro de un solo invoke.
- **Lectura de secretos sin cache** — `secretsmanager:GetSecretValue` en cada invoke paga por request y añade latencia. Cachear fuera del handler.
- **`print`** — usar `logging` para poder controlar nivel y formato. CloudWatch acepta ambos pero `print` suele acabar en una línea por carácter en frameworks que redirigen stdout.
- **Dependencias no usadas** — cada MB en el deployment package suma al cold start.

## 6. Preguntas de autocomprobación

1. ¿Qué pasa si pones `boto3.client("s3")` **dentro** del handler? ¿Cambia el cold start, el precio o ambos?
2. Si una invocación recibe 10 mensajes en el batch SQS y el 7º falla, ¿se reintentan los 10 o solo el 7º? ¿Qué knob controla esto?
3. `context.aws_request_id` vive mientras dura la invocación. Si tu handler lanza un thread, ¿puedes seguir leyéndolo desde el thread? ¿Deberías?
4. Si tu handler tarda 300 ms en el 99% de los casos y 12 s en el 1%, ¿con qué `VisibilityTimeout` configurarías la cola SQS que lo invoca?

Las respuestas se trabajan en las actividades.
