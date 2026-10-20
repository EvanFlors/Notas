# Ejemplo 02 — Diagrama de un pipeline event-driven S3 → Lambda → SNS → SQS → Lambda

> Lectura y análisis. Objetivo: visualizar un pipeline event-driven típico y **marcar las zonas de riesgo** (dónde se pierden mensajes, dónde se duplican, dónde se dispara la factura).

## 1. El escenario

> Un usuario sube una imagen a S3. Hay que:
> 1. generar una versión thumbnail,
> 2. notificar a un canal interno de que hay una nueva imagen,
> 3. actualizar un índice en una base de datos.

Tres consumidores independientes para **un mismo evento**. Caso canónico de **fanout**.

## 2. Topología recomendada

```
                       ┌───────────────┐
    Upload HTTP ───►   │ S3 bucket     │  s3:ObjectCreated:* event
                       │  uploads/     │─────────────────────┐
                       └───────────────┘                     │
                                                             ▼
                                      ┌─────────────────────────┐
                                      │ Lambda: EventRouter     │
                                      │  (validar, normalizar,  │
                                      │   publicar a SNS)       │
                                      │  idempotente por        │
                                      │   object_key+etag       │
                                      └──────────┬──────────────┘
                                                 │ PutRecord
                                                 ▼
                                      ┌─────────────────────────┐
                                      │ SNS Topic: image-uploaded│
                                      └──┬───────┬───────────┬──┘
                                         │       │           │
                                 ┌───────┘       │           └────────┐
                                 ▼               ▼                    ▼
                        ┌───────────────┐  ┌──────────────┐  ┌──────────────┐
                        │ SQS: thumbs   │  │ SQS: notify  │  │ SQS: index   │
                        │ VisTO=180s    │  │ VisTO=30s    │  │ VisTO=60s    │
                        │ DLQ→thumbs-DLQ│  │ DLQ→notify-DL│  │ DLQ→index-DL │
                        │ maxReceive=5  │  │ maxReceive=3 │  │ maxReceive=5 │
                        └───────┬───────┘  └──────┬───────┘  └──────┬───────┘
                                │                 │                 │
                                ▼                 ▼                 ▼
                        ┌───────────────┐  ┌──────────────┐  ┌──────────────┐
                        │ Lambda:       │  │ Lambda:      │  │ Lambda:      │
                        │  Thumbnailer  │  │  Notifier    │  │  Indexer     │
                        │  (Pillow)     │  │ (Slack/HTTP) │  │ (DDB upsert) │
                        └───────┬───────┘  └──────┬───────┘  └──────┬───────┘
                                │                 │                 │
                                ▼                 ▼                 ▼
                        ┌───────────────┐  ┌──────────────┐  ┌──────────────┐
                        │ S3: thumbs/   │  │ Slack webhook│  │ DynamoDB     │
                        │               │  │              │  │  table images│
                        └───────────────┘  └──────────────┘  └──────────────┘
```

## 3. Lectura del diagrama

### 3.1 Por qué un EventRouter al principio

En lugar de que S3 dispare 3 Lambdas distintas (lo que **sí** se puede hacer con S3 event notifications), usamos **una** Lambda que valida y normaliza antes de empujar al topic. Ventajas:

- **Centraliza** la validación del evento S3 (un bug en el shape afecta a un solo sitio).
- Convierte el evento S3 (grande, con metadata de bucket + object) en un **payload de dominio** más pequeño (`{"object_key": "...", "etag": "...", "mime": "..."}`) que los consumers reciben.
- Permite **enriquecer** (p. ej., leer tamaño del objeto, mimetype) una vez y propagar a los 3.

Trade-off: añade una Lambda y un cold start al pipeline. Si no necesitas enriquecer y S3 → Lambda directo basta, puedes saltarte el router.

### 3.2 Por qué SNS → SQS en vez de SNS → Lambda directo

Opción corta: SNS puede entregar a Lambda directamente, sin SQS. **No lo hagas en producción.**

Razones:

- Si la Lambda del subscriber está caída (bug nuevo, throttle), SNS reintenta con backoff y **puede acabar perdiendo** mensajes tras `MaxReceiveCount`. **No hay buffer**.
- Con SQS en medio: los mensajes se acumulan en la cola mientras arreglas el bug. El `MaxReceiveCount` + DLQ aísla los venenosos.
- Da **independencia operativa** por consumer: puedes vaciar la cola `thumbs` sin tocar `notify`.
- La cola **absorbe spikes** de tráfico que spikerían la Lambda directamente.

Regla: **SNS directo a Lambda solo para notificaciones donde perder mensajes es aceptable** (p. ej., email de bienvenida low-stakes). Para pipelines, siempre SNS → SQS → Lambda.

### 3.3 Visibility timeout por consumer

Cada cola tiene su **propio** `VisibilityTimeout` según cuánto tarda su worker:

- `thumbs`: 180 s (procesar imagen con PIL puede tardar varios segundos; margen = 6x).
- `notify`: 30 s (HTTP a Slack es casi instantáneo; margen pequeño pero suficiente).
- `index`: 60 s (DDB `PutItem` es rápido pero con reintentos propios).

Si pusiéramos el mismo valor a todos, o perderíamos mensajes en `thumbs` (muy corto) o retrasaríamos retries en `notify` (muy largo).

### 3.4 DLQ y `maxReceiveCount`

Toda cola tiene DLQ. `maxReceiveCount` dice cuántas veces reintenta antes de que un mensaje vaya a la DLQ:

- `thumbs` y `index`: 5 (algunos errores transitorios como throttles de S3 o DDB se resuelven solos).
- `notify`: 3 (si Slack falla 3 veces es porque algo serio pasa; mejor DLQ y una alarma que seguir intentando).

**Toda DLQ tiene una alarma** `ApproximateNumberOfMessagesVisible > 0`. Si no, es DLQ "donde los mensajes van a morir en silencio".

### 3.5 Idempotencia donde importa

- **EventRouter**: key = `object_key + etag` (S3 puede entregar el evento más de una vez; el etag garantiza que "mismo objeto, misma versión" se traduce al mismo key).
- **Thumbnailer**: el output S3 `thumbs/{key}` **es** idempotente por sí mismo (`PutObject` sobrescribe).
- **Notifier**: Slack no es idempotente de forma natural; necesita tabla auxiliar `(message_hash → sent_at)` para evitar double-post.
- **Indexer**: DDB upsert por `object_key` (PK) es naturalmente idempotente.

## 4. Zonas de riesgo marcadas

```
   RIESGO 1: S3 → EventRouter
     - S3 puede entregar el mismo evento más de una vez (at-least-once).
     - Mitigación: idempotencia por object_key+etag en EventRouter.

   RIESGO 2: EventRouter → SNS
     - PutRecord puede fallar (throttle, API error).
     - Mitigación: retry con backoff dentro del router + DLQ propia
       (fallo de router = DLQ de router, no se publica al topic).

   RIESGO 3: SNS → SQS
     - Entrega best-effort con retries internos de SNS.
     - Mitigación: SQS retiene aunque el consumer esté caído.

   RIESGO 4: SQS → Lambda (consumer)
     - At-least-once. Puede procesar el mismo mensaje 2+ veces.
     - Mitigación: idempotencia del handler + VisTO adecuado.

   RIESGO 5: Consumer → side-effect externo (Slack, DDB, S3)
     - El side-effect puede fallar a mitad.
     - Mitigación: side-effect idempotente o compensación.

   RIESGO 6: DLQ sin alarma
     - Mensajes mueren en silencio.
     - Mitigación: CloudWatch alarm por mensaje en DLQ.

   RIESGO 7 (costo): Lambda chatty + logs sin retention
     - Factura CloudWatch Logs puede superar la de invocaciones.
     - Mitigación: retention 7–30 días, logs estructurados compactos.
```

## 5. Variaciones comunes

- **Reemplazar SNS por EventBridge** cuando necesitas filter policies más expresivos (JSON pattern con `anything-but`, `prefix`, `numeric`, etc.) o cross-account.
- **Reemplazar SQS por EventBridge Pipes** si el enrichment es un paso simple sin lógica compleja (menos Lambdas).
- **Reemplazar los 3 Lambdas consumidores por Step Functions** si quieres orquestarlos secuencial o condicionalmente (p. ej., "si el thumbnailer falla, no notifiques").
- **Usar FIFO (SNS FIFO + SQS FIFO) con `MessageGroupId=object_key`** si necesitas que las 2 actualizaciones consecutivas del mismo objeto se procesen en orden.

## 6. Preguntas de autocomprobación

1. Si borras la DLQ de `notify`, ¿qué pasa con los mensajes que fallan 3 veces? ¿Dónde van?
2. ¿Por qué el `VisibilityTimeout` de `thumbs` es 180 s si el procesamiento tarda ~20 s? ¿No es excesivo?
3. Si cambias SNS por EventBridge y pones un patrón `{"detail": {"mime": [{"prefix": "image/"}]}}`, ¿qué consumidores dejan de recibir eventos de PDFs subidos al bucket? ¿Es lo que quieres?
4. ¿Qué pasa si el `EventRouter` publica correctamente a SNS pero muere **antes de devolver 200** a S3? ¿Cuántas copias llegarán a los consumers?

Las respuestas se trabajan en la actividad `02-event-driven-design-decisions`.
