# aws-14 — Lección: serverless para integraciones

> 12 secciones. Lo justo de serverless para integraciones y automatizaciones. **No** un reemplazo de ECS/EKS para workloads largos ni un tratado exhaustivo.

---

## 1. Qué entendemos por "serverless" en este módulo

"Serverless" en AWS cubre decenas de servicios. En este módulo nos interesan solo los que resuelven **integraciones**: pegar un evento con una acción corta, orquestar varios pasos y notificar.

Las 6 piezas que vamos a trabajar:

- **Lambda** — ejecución de código por evento, pay-per-invoke + GB-s.
- **API Gateway** — exponer HTTP(S) hacia Lambda u otros targets.
- **EventBridge** — bus de eventos (default + custom buses), routing por patrón.
- **SQS** — cola de mensajes con durabilidad; standard o FIFO.
- **SNS** — pub/sub topics, fanout a múltiples subscribers.
- **Step Functions** — orquestación de flujos con reintentos y branching.

Lo que **no** cubrimos aquí: Kinesis, MSK, DynamoDB Streams, AppFlow, AppRunner. No porque no sean serverless, sino porque viven en otros módulos.

Idea rectora de todo el módulo:

> **Serverless es un contrato de operabilidad, no de programación.** Lo distinto no es cómo escribes el código; es qué dejas de operar (el runtime, el autoscaler, el patching del SO). Lo que paga ese contrato son nuevas restricciones (duración máxima, cold starts, estado efímero) que **tienes que diseñar**.

---

## 2. Lambda: el modelo mental correcto

### 2.1 La vida de una Lambda

```
   evento llega ───► ¿hay instancia caliente?
                       │
          sí ─────────┘             └──► no
          │                              │
          │                              ▼
          │                     cold start:
          │                       1. descargar artefacto
          │                       2. init del runtime
          │                       3. ejecutar código fuera del handler
          │                              │
          └──────────────────────────────┤
                                         ▼
                                    invoke(handler)
                                         │
                                         ▼
                                   freeze instance
                                         │
                            (reutilizable minutos)
                                         │
                                   shutdown eventual
```

Cuatro consecuencias de este modelo:

1. **Lo que está "fuera del handler" se ejecuta una vez por instancia.** Clientes AWS, conexiones a DB, carga de modelos: inicialízalos ahí. Dentro del handler, reutilízalos.
2. **El `freeze` guarda estado en memoria.** Variables globales **persisten** entre invocaciones **de la misma instancia**. Puede ser una ventaja (cache) o una pistola apuntando al pie (fugas, datos de un request filtrados en otro).
3. **No controlas cuándo se destruye la instancia.** Nada que necesite shutdown gracioso debería vivir dentro de Lambda.
4. **Cold starts cuestan.** Python ligero: 100–300 ms. Container image grande: 2–8 s. SnapStart (Java/Python ciertos) reduce a decenas de ms a cambio de snapshotting.

### 2.2 Memoria = CPU

La memoria asignada **determina la CPU proporcionalmente**. Pasar de 512 MB a 1024 MB no solo da el doble de RAM: da aproximadamente el doble de vCPU. Para funciones CPU-bound (procesar JSON grande, PIL, compresión), subir memoria **puede bajar la factura total** porque la invocación dura menos ms-GB. Hay que medir caso a caso con el **Lambda Power Tuning** (herramienta oficial basada en Step Functions, enlaces en `resources/`).

### 2.3 Concurrencia

- **Concurrencia por default**: hasta **1000 ejecuciones simultáneas por región, compartidas entre todas las funciones**. No es "1000 por función".
- **Reserved concurrency**: reservar un slot fijo para una función crítica. Baja el pool compartido en ese número.
- **Provisioned concurrency**: pre-calentar N instancias para eliminar cold starts (se paga aunque no se usen).
- Un **spike** que exceda el pool genera `Throttle` (API) o retries silenciosos (eventos async / SQS).

### 2.4 Timeouts

Máximo **15 minutos**. Si tu lógica llega cerca de ese límite, es señal de que **no debería ser Lambda** — ver §9.

---

## 3. API Gateway: REST vs HTTP vs WebSocket

Hay tres sabores. El error típico es elegir **REST** cuando lo correcto es **HTTP**.

| Sabor | Cuándo | Costo relativo | Observación |
|-------|--------|---------------|-------------|
| **REST** | Features avanzados: usage plans + API keys, request/response transformations, caching, WAF detallado, private endpoints con VPC Link v1. | ~3x más caro por request. | Es el "producto completo" de API GW; úsalo si **necesitas** sus features. |
| **HTTP** | API moderna HTTP/2, JWT authorizer nativo, OIDC, CORS simple, Lambda proxy. | Barato. | **Default razonable** para APIs nuevas. |
| **WebSocket** | Conexiones persistentes bidireccionales (chat, notificaciones push, trading). | Billing por conexión + mensaje. | Modelo de rutas distinto (`$connect`, `$disconnect`, custom). |

El **Lambda proxy integration** convierte el request HTTP en un `event` con una estructura fija y envía la respuesta de la Lambda al cliente. Es el modo recomendado — las "non-proxy" integrations con velocity templates son potentes pero convierten tu API en una caja negra difícil de debuggear.

**Costo oculto**: cada request de API Gateway cuesta aparte de la Lambda. Para APIs de alto volumen (millones/día), el costo de API GW puede superar al de la Lambda.

---

## 4. EventBridge: el router de eventos

### 4.1 Primitivos

- **Bus**: canal de eventos. El `default` bus recibe eventos de servicios AWS. Puedes crear **custom buses** para eventos de tu dominio (`checkout-events`, `billing-events`).
- **Rule**: patrón que matchea eventos del bus y los enruta a 1..N targets.
- **Target**: destino del evento (Lambda, SQS, SNS, Step Functions, API Destination externa, otro bus...).

### 4.2 Patrón de evento

Un patrón filtra por campos del evento:

```json
{
  "source": ["myapp.checkout"],
  "detail-type": ["OrderPlaced"],
  "detail": {
    "amount": [{ "numeric": [">=", 100] }]
  }
}
```

Esto permite "una sola Lambda por tipo de evento" sin que la Lambda haga `if event["detail-type"] == ...` como primera línea.

### 4.3 Pipes

**EventBridge Pipes** (2022) es la pieza menos conocida y más útil para integraciones: `source → filter → enrichment → target` sin Lambda intermedia. Un pipe puede leer de SQS, filtrar mensajes, enriquecerlos llamando a una Lambda y empujarlos a un Step Function. Antes de pipes hacía falta una Lambda de "glue" en cada paso.

### 4.4 Cross-account

Eventos pueden cruzar cuentas vía `PutEvents` con `EventBusName` apuntando a un bus de otra cuenta (requiere resource policy). Es el patrón canónico para enviar eventos desde cuentas de workload a una cuenta central de observabilidad/audit.

---

## 5. SQS: `standard` vs FIFO, y por qué DLQ no es opcional

### 5.1 Standard

- **At-least-once delivery**. Un mensaje puede llegar **2 o más veces**. El consumer tiene que ser **idempotente**.
- **Fuera de orden**: ninguna garantía de orden.
- Throughput prácticamente ilimitado.
- Precio bajo.

### 5.2 FIFO

- **Exactly-once procesamiento** dentro de la ventana de deduplicación (5 min por default usando `MessageDeduplicationId`).
- **Orden garantizado por `MessageGroupId`**: todos los mensajes del mismo grupo se procesan en orden; distintos grupos van en paralelo.
- Throughput limitado: 300 msg/s por grupo (3000/s con "high throughput mode").
- **Más caro por request** que standard.

### 5.3 Visibility timeout

Cuando un consumer hace `ReceiveMessage`, el mensaje queda **invisible** por N segundos para que nadie más lo procese. Si el consumer termina en ese tiempo y hace `DeleteMessage`, bien. Si **no**, el mensaje reaparece y será reentregado.

Regla práctica: **`VisibilityTimeout = 6 × tiempo medio de procesamiento`** (según la propia guía de AWS). Demasiado corto → mensaje reaparece antes de que termines, procesas dos veces. Demasiado largo → si el consumer muere, el mensaje tarda en volver a estar disponible.

### 5.4 DLQ y `maxReceiveCount`

Una **Dead Letter Queue** es una SQS secundaria donde van los mensajes que han sido reentregados **más de N veces** (`maxReceiveCount`) sin éxito. Sin DLQ, un mensaje "venenoso" (que siempre falla) **bloquea** la cola para siempre y consume invocaciones Lambda sin parar.

Regla: **toda cola productiva tiene DLQ**. Y la DLQ tiene **alarma** por `ApproximateNumberOfMessagesVisible > 0` que despierta a un humano.

### 5.5 Long polling

`ReceiveMessageWaitTimeSeconds = 20` (máximo) activa **long polling**: la llamada espera hasta 20 s a que llegue un mensaje antes de responder vacío. Reduce coste de polling y latencia. Es el default razonable; el default "0" (short polling) es el peor de los dos mundos.

---

## 6. SNS: pub/sub con fanout

- **Topic**: canal pub/sub. Un publisher envía, N subscribers reciben una copia cada uno.
- **Subscribers**: SQS (el más usado para fanout confiable), Lambda, HTTPS, email, SMS, otros topics (chained), Kinesis Firehose.
- **FIFO topics**: existen; combinan con FIFO SQS para preservar orden a través del fanout.
- **Filter policies**: cada subscription puede filtrar mensajes por atributos sin que el publisher tenga que saber de los subscribers.

Patrón canónico: **SNS → SQS fanout**. El publisher emite un mensaje a un topic; N colas SQS lo reciben; N consumers independientes lo procesan sin acoplarse. Si un consumer está caído, su cola se llena y luego recupera — los demás no se enteran.

Diferencia conceptual rápida:

```
   SQS: 1 publisher → 1 cola → 1..N consumers (uno procesa cada mensaje)
   SNS: 1 publisher → 1 topic → N subscribers (todos reciben cada mensaje)
```

---

## 7. Step Functions: orquestar sin pegamento

### 7.1 Standard vs Express

- **Standard**: durabilidad hasta 1 año de ejecución, pago **por transición de estado**. Para flujos de negocio (checkout, onboarding, pipeline de ML).
- **Express**: hasta 5 min de duración, pago **por request + duración**. Para flujos cortos de alta volumen (procesamiento por ítem, high-throughput ETL).

### 7.2 ASL (Amazon States Language) — el mínimo

```json
{
  "Comment": "Ejemplo didactico",
  "StartAt": "ValidarPedido",
  "States": {
    "ValidarPedido": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "arn:aws:lambda:us-east-1:123456789012:function:ValidarPedido",
        "Payload.$": "$"
      },
      "Next": "EsPremium"
    },
    "EsPremium": {
      "Type": "Choice",
      "Choices": [
        { "Variable": "$.customer.tier", "StringEquals": "premium", "Next": "RutaPremium" }
      ],
      "Default": "RutaStandard"
    },
    "RutaPremium": { "Type": "Pass", "End": true },
    "RutaStandard": { "Type": "Pass", "End": true }
  }
}
```

Estados que debes conocer:

- `Task` — invoca algo (Lambda, servicio AWS directo vía service integration, Activity).
- `Choice` — branching por valor del input.
- `Parallel` — N ramas en paralelo, espera a todas.
- `Map` — iterar sobre un array (standard o distributed mode).
- `Wait` — esperar N segundos o hasta timestamp.
- `Pass` — no-op útil para tests y para transformar input/output.
- `Succeed` / `Fail` — terminales.

### 7.3 Retry y Catch

Cada `Task` puede declarar reintentos por tipo de error con backoff:

```json
"Retry": [
  {
    "ErrorEquals": ["Lambda.TooManyRequestsException"],
    "IntervalSeconds": 2,
    "MaxAttempts": 3,
    "BackoffRate": 2.0
  }
],
"Catch": [
  { "ErrorEquals": ["States.ALL"], "Next": "CompensarPedido" }
]
```

Esto reemplaza decenas de líneas de `try/except` + sleep en código Lambda. **Reintentar en Step Functions es gratis en código**; se paga por transición extra.

### 7.4 Service integrations directas

Step Functions puede llamar a servicios AWS **sin Lambda intermedia**: `arn:aws:states:::sqs:sendMessage`, `arn:aws:states:::dynamodb:putItem`, `arn:aws:states:::sns:publish`. Esto elimina Lambdas de "glue" (que solo hacen "recibí evento, llamo a servicio X y devuelvo"), reduciendo costo y complejidad.

---

## 8. Idempotencia: el requisito silencioso

Como SQS standard es **at-least-once** y Lambda puede reintentar invocaciones async, **todo handler que modifique estado tiene que ser idempotente**. Si no, un reintento duplica cargos, inserta pedidos dos veces, envía dos emails.

Técnicas:

1. **Clave idempotente derivada del input**. Si procesas `OrderPlaced` con `order_id=42`, usa `order_id` como PK en el side-effect (`DynamoDB PutItem` con `ConditionExpression attribute_not_exists`).
2. **Tabla de operaciones ya hechas**. Al entrar al handler, insertas `(request_id, status=in_progress)` con condition "no existe"; si falla el condition, es un retry y sales. Al terminar, marcas `done`.
3. **`lambda-powertools idempotency`** (opcional): decorator `@idempotent` que gestiona lo anterior contra DynamoDB. Útil cuando lo haces en varios handlers.
4. **Operaciones naturalmente idempotentes**: upserts (`PUT` en lugar de `POST`), `set` en lugar de `increment`, "último valor gana".

La idempotencia es un **requisito de diseño**, no un detalle de implementación. Diseñar un handler no idempotente y "esperar a que no haya retries" es cómo se pierden pedidos en producción.

---

## 9. Lambda vs ECS vs EKS: el criterio

Preguntas en orden:

1. **¿La invocación individual dura > 15 min?** → No es Lambda. ECS/Fargate o EKS.
2. **¿Es carga steady > 50% del día?** → Lambda sale caro contra una tarea Fargate siempre encendida. Haz la cuenta: `invocaciones/mes × duración × GB-s`.
3. **¿Necesitas conexiones persistentes (WebSocket largo, long-polling, agentes conectados)?** → Lambda sirve si duran < 15 min; para 24/7 reales, un contenedor.
4. **¿Toleras cold starts de 300 ms–8 s en el 1% peor?** → Si no, provisioned concurrency (cara) o contenedor.
5. **¿Es un cron sencillo (una vez al día o cada N min)?** → EventBridge + Lambda es imbatible en costo y simplicidad.
6. **¿Es un evento disperso (S3, SNS, DynamoDB Streams)?** → Lambda es el default; nada más es tan directo.
7. **¿El equipo ya opera EKS?** → Jobs cortos en EKS CronJob + KEDA pueden ser aceptables si evita arrastrar otra plataforma.

Cuadro rápido:

```
   ┌───────────────────────┬─────────────────────────────────────┐
   │ Caso                  │ Elección razonable                  │
   ├───────────────────────┼─────────────────────────────────────┤
   │ S3 trigger            │ Lambda                              │
   │ Cron diario < 15 min  │ EventBridge Schedule + Lambda       │
   │ API HTTP bursty       │ API GW HTTP + Lambda                │
   │ API HTTP sostenida    │ ALB + ECS/Fargate                   │
   │ Worker steady 24/7    │ ECS/Fargate (ECS Service, 1..N)     │
   │ Job batch 1h+         │ ECS Task + EventBridge Schedule     │
   │ Pipeline multi-paso   │ Step Functions (+ Lambdas / direct) │
   │ WebSocket chat        │ API GW WebSocket + Lambda           │
   └───────────────────────┴─────────────────────────────────────┘
```

---

## 10. Costos ocultos (los 3 que arruinan presupuestos)

1. **Logs de Lambda a CloudWatch Logs.** Cada `print` o `logger.info` es ingesta pagada ($0.50/GB en región estándar) + storage. Una Lambda muy chatty puede costar más en logs que en invocaciones. Palancas: nivel `INFO` → `WARN` por default, logs estructurados compactos, **log retention** finito (7–30 días), exportar a S3 si hay regulación de 1 año.
2. **EventBridge events-per-second.** $1 por millón de eventos custom + $0 para eventos AWS. Un sistema que publica un evento por cada click puede llegar a cifras serias. Palanca: **agrupar** eventos (ya sea en origen o con `PutEvents` batch) y preguntarse si realmente hace falta ese evento.
3. **API Gateway requests.** REST: ~$3.50 por millón. HTTP: ~$1.00 por millón. Para una API con 100M req/mes la diferencia es $250 vs $100 **solo en API GW** antes de contar Lambda. Palanca: elegir HTTP salvo que REST sea realmente necesario, cachear donde se pueda.

Costos **menos obvios** pero reales: NAT Gateway cuando una Lambda vive en VPC y llama a Internet (cada byte sale por NAT, cobrado por GB), DLQ "olvidada" (si nunca se procesa, no cuesta mucho — pero si está detrás de SNS que insiste, el costo escala), `Provisioned concurrency` encendida y olvidada en entornos pre-prod.

---

## 11. Observabilidad mínima de serverless

Dos capas:

### 11.1 Nativa AWS

- **CloudWatch Logs**: cada Lambda tiene su log group `/aws/lambda/<name>`. Retención por default es **nunca expira** — fijar `retention_in_days` siempre.
- **CloudWatch Metrics**: cada Lambda emite `Invocations`, `Errors`, `Throttles`, `Duration`, `ConcurrentExecutions` sin instrumentar nada.
- **X-Ray**: tracing distribuido nativo AWS. Útil, pero menos portable que OTel.

### 11.2 Vendor-neutral (recomendado para el futuro)

- **AWS Lambda Powertools for Python** (`aws-lambda-powertools`): logging estructurado JSON, metrics EMF (Embedded Metric Format que CloudWatch parsea sin agente), tracer compatible con X-Ray/OTel, parser de events, idempotency, batch processing. Es **opcional** pero recomendado — un `handler` con `@logger.inject_lambda_context`, `@tracer.capture_lambda_handler`, `@metrics.log_metrics` tiene observabilidad decente desde el día 1 con 3 decorators.
- **OpenTelemetry en Lambda**: se puede, pero añade cold start. Para integraciones puntuales, Powertools + EMF suele ser mejor relación coste/beneficio. Para microservicios en Lambda, OTel vale la pena.

El `examples/01-lambda-handler-anatomy/` muestra un handler razonable sin Powertools (puro stdlib) y menciona cómo quedaría con Powertools.

---

## 12. Qué llevarte

Al terminar este módulo deberías poder, delante de un diagrama en pizarra:

- Dibujar el **ciclo de vida** de una Lambda (`init → invoke → freeze → shutdown`) y señalar dónde van los clientes AWS.
- Dado "un evento llega a este sistema", trazar la ruta `source → bus → target` con 1..N colas, DLQ incluidas y `VisibilityTimeout` razonable.
- Decidir Lambda vs ECS para 3 workloads sin consultar nada.
- Leer una ASL de 10 estados y explicar qué hace y qué pasa si uno falla.
- Nombrar 3 costos ocultos y qué knob los controla.

Una síntesis final de una línea:

> **Serverless en AWS es la mejor opción para integraciones event-driven cortas, bursty y stateless; para todo lo demás, un contenedor sigue siendo lo correcto y lo más barato.**

Lo que **sigue**:

- `aws-15` — multi-cuenta y gobernanza (donde los eventos cruzan cuentas de verdad).
- `aws-16` — DevSecOps sobre AWS (OIDC → Lambda deploys sin keys).
- Proyecto capstone — un mini-pipeline event-driven provisto con Terraform contra una cuenta AWS real.
