# REFERENCE — aws-14-02-event-driven-design-decisions

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Sección A — Compute (modelo)

| Subcaso | Elección | Justificación |
|---------|----------|---------------|
| 1. Thumbnailer (por subida) | **Lambda** | Carga bursty (depende de uploads de usuarios), duración por invoke corta (1–10 s), stateless. Memoria=1024 MB para PIL. Cold start aceptable. |
| 2. Notifier (webhook Slack) | **Lambda** | HTTP a Slack dura < 1 s. Volumen bajo. El coste casi es despreciable. |
| 3. Indexer (DDB upsert) | **Lambda** | `PutItem` es prácticamente instantáneo. Igual que notifier. |
| 4. Batch PDF diario (20–45 min) | **ECS/Fargate task** disparada por EventBridge Schedule | Lambda tiene timeout **15 min** — un batch de 45 min **no cabe**. Fargate task permite ejecutar un contenedor con duración arbitraria, se apaga al terminar, no paga 24/7. Alternativa: Step Functions con Map distribuido troceando por hora → N Lambdas de ≤ 15 min cada una. |

## Sección B — Topología (modelo)

### Diagrama

```
   S3 bucket (uploads/) ──s3:ObjectCreated:*──► Lambda: EventRouter
                                                     │
                                                     │ SNS Publish
                                                     ▼
                                             SNS Topic: image-uploaded
                                                     │
                       ┌─────────────────────────────┼─────────────────────────────┐
                       ▼                             ▼                             ▼
                 SQS: thumbs                   SQS: notify                   SQS: index
                 VisTO=180s, maxRecv=5         VisTO=30s, maxRecv=3          VisTO=60s, maxRecv=5
                 DLQ: thumbs-dlq               DLQ: notify-dlq               DLQ: index-dlq
                       │                             │                             │
                       ▼                             ▼                             ▼
                 Lambda: Thumbnailer           Lambda: Notifier              Lambda: Indexer
                   (PIL, 1024 MB)                 (urllib, 128 MB)             (boto3 DDB, 256 MB)
                       │                             │                             │
                       ▼                             ▼                             ▼
                 S3 (thumbs/{key})             Slack webhook               DynamoDB images
```

### Idempotencia donde importa

- `EventRouter`: idempotente por `object_key + etag` (S3 puede entregar el mismo evento más de una vez).
- `Thumbnailer`: `PutObject` sobre `thumbs/{key}` es naturalmente idempotente (sobrescribe).
- `Notifier`: **requiere** tabla auxiliar `(hash → sent_at)` o retries podrían postear doble.
- `Indexer`: `PutItem` por `object_key` como PK es naturalmente idempotente.

### Parámetros por cola

| Cola | FIFO/Std | VisTO | maxReceiveCount | DLQ | Justificación |
|------|----------|-------|-----------------|-----|---------------|
| thumbs | Standard | 180 s | 5 | thumbs-dlq | 6× el tiempo medio de procesamiento (~30 s). `MaxRecv=5` permite reintentar errores transitorios de S3/throttles. |
| notify | Standard | 30 s | 3 | notify-dlq | Slack responde en < 1 s; 30 s es sobrado. Rate limits de Slack son el fallo típico — 3 reintentos, luego DLQ + alarma. |
| index | Standard | 60 s | 5 | index-dlq | DDB es rápido pero puede throttlear con write capacity bursts; 60 s + 5 reintentos cubren el caso. |

Todas tienen `ReceiveMessageWaitTimeSeconds=20` (long polling, default sano).

## Sección C — FIFO vs Standard (modelo)

- **thumbs**: Standard. No importa el orden (cada foto es independiente). FIFO limitaría a 300 msg/s por grupo sin ganancia real.
- **notify**: Standard. Si publican dos fotos "a la vez", no es problema que las notificaciones lleguen en cualquier orden. Si Slack recibe duplicados, los deduplica el notifier con su tabla auxiliar.
- **index**: Standard. DDB upsert por PK **no** depende del orden. Un argumento a favor de FIFO sería que si se re-sube la **misma** foto (mismo `object_key`), queramos garantizar que la última versión gana — pero eso se resuelve mejor con un atributo `last_modified` en el item y una `ConditionExpression`, no con FIFO.

**Caso donde FIFO sí ganaría**: si el flujo fuese "actualizaciones de un carrito de compra" donde el **orden** de los eventos cambia el estado final (`add_item` seguido de `remove_item` ≠ `remove_item` seguido de `add_item`), entonces FIFO con `MessageGroupId=cart_id` sería obligatorio. **No es este caso**.

## Sección D — Costos ocultos (modelo)

1. **CloudWatch Logs** — cada log del handler se ingesta ($0.50/GB) + storage. Palanca: nivel `INFO` sobrio, `retention_in_days=14`, logs estructurados sin texto redundante.
2. **SNS → SQS cross-region traffic** — si pones el topic en una región y las colas en otra, cada mensaje paga egress. Palanca: mantener topic y colas en la misma región.
3. **Lambda invocations + GB-s en el Thumbnailer** — subir memoria baja duración; medir con Lambda Power Tuning para encontrar el sweet-spot. Palanca: memoria entre 512–2048 MB, elegida por medición no por intuición.
4. **(Bonus) DLQ olvidada sin alarma** — mensajes acumulándose indefinidamente también cuentan como "costo oculto" porque el bug asociado sigue sangrando. Palanca: `CloudWatch Alarm` sobre `ApproximateNumberOfMessagesVisible > 0` por cada DLQ.
5. **(Bonus) EventBridge Schedule para el batch PDF** — gratuito si lo pones como rule; si usas EventBridge Scheduler (nuevo), cuesta por invocación. Palanca: para un cron diario, cualquiera; para schedules muy numerosos, revisar.

## Sección E — ASL JSON (modelo)

Ver `pdf-report.asl.json` adjunto al README como plantilla. Un diseño sensato para el batch PDF usaría:

- `Task` para listar fotos del día (DDB query o S3 ListObjects via Lambda).
- `Choice` para abortar temprano si no hay fotos.
- `Map` (distributed mode) para procesar fotos en paralelo si el batch de 45 min viene de la **cantidad**; cada iteración en una Lambda ≤ 15 min.
- `Task` final para componer el PDF con los resultados.
- `Catch` global que empuje a una Lambda de notificación de fallo.
- `Retry` en los Task individuales con `BackoffRate=2.0` para transientes.

Alternativa sin Step Functions: `EventBridge Schedule` → `ECS RunTask` sobre un contenedor Fargate con el script completo. Más simple, menos observable paso-a-paso.

## Punto a repetir

> Diseñar event-driven no es "pongo Lambdas y SQS entre medias". Es decidir **al milímetro** qué pasa cuando algo falla, cuánto cuesta cada eslabón y quién **se entera** cuando los mensajes se mueren en una DLQ.
