# Lección: Context propagation across services

## 1. El problema: traces "cortos"

Cuando se instrumenta un primer servicio con OTel y se ve un trace precioso en Tempo con 20 spans, es fácil asumir que todo funciona. El síntoma de propagación rota aparece cuando ese servicio llama a otro: en vez de **un** trace con dos subárboles, aparecen **dos** traces separados, cada uno con `trace_id` distinto. En Grafana se ven como "waterfalls" cortos y desconectados.

La causa es casi siempre la misma: el servicio B no recibió — o no entendió — el `traceparent` que el servicio A debería haber enviado como header HTTP (o metadata gRPC, o Kafka header). El SDK, al no encontrar un parent, decide "soy un root span nuevo" y arranca su propio trace.

**Context propagation** es el conjunto de convenciones y mecanismos que mantienen esa correlación a través de hops. Es la pieza que convierte N servicios en **un sistema observable**.

## 2. Dos niveles: context in-process vs context wire-level

El context de OTel vive en dos planos distintos y confundirlos genera bugs sutiles:

- **In-process context**: dentro de un proceso, el context "actual" se guarda en una `contextvars.ContextVar` (en Python). Cuando abres un span con `start_as_current_span`, el nuevo span se registra como "current" en el context. Cualquier llamada dentro de ese `with` ve ese span como parent — automáticamente, sin pasarlo como argumento.
- **Wire-level context**: entre procesos no viaja la `ContextVar`. Viaja un **texto serializado** del context (headers HTTP, metadata gRPC, Kafka headers). El estándar más común es **W3C Trace Context**: un header `traceparent` con el formato `00-<trace-id>-<span-id>-<flags>`.

El puente entre los dos planos son dos funciones:

```python
from opentelemetry.propagate import inject, extract

# emisor
headers = {}
inject(headers)              # serializa el current context en headers
http_client.post(url, headers=headers)

# receptor
ctx = extract(request.headers)   # reconstruye un context remoto
with tracer.start_as_current_span("handle", context=ctx):
    ...
```

Sin `extract`, el receptor pierde el parent y empieza un trace nuevo. Sin `inject`, el emisor envía la request "desnuda" y el receptor (aun con `extract` configurado) no encuentra qué extraer.

## 3. W3C Trace Context en detalle

El header `traceparent` tiene cuatro campos separados por guión:

```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
             │  │                                │                │
             │  │                                │                └── trace-flags (01 = sampled)
             │  │                                └── parent-id (span padre del receptor)
             │  └── trace-id (128 bits, estable a través de todos los hops)
             └── version (00 = W3C 1.0)
```

El `tracestate` header es un acompañante vendor-specific (`tracestate: dd=…,otel=…`), opcional pero útil para hints de sampling consistente (`otel=rv:<...>`).

El `baggage` header propaga **valores de negocio arbitrarios** (`baggage: user.tier=gold,region=eu-west-1`). Útil para enriquecer spans downstream pero peligroso: todo lo que mandas por baggage viaja en **cada hop**; si lo copias a attributes de span, puede explotar la cardinalidad de tus métricas.

## 4. HTTP: propagación "gratis" con instrumentations

Para HTTP, las instrumentation libraries ya resuelven la propagación. En Python:

- `opentelemetry-instrumentation-fastapi` hace `extract` en cada request y abre un server span.
- `opentelemetry-instrumentation-httpx` / `requests` hacen `inject` en cada outbound request y abren un client span.

Lo único que debes hacer es:

```python
FastAPIInstrumentor.instrument_app(app)
HTTPXClientInstrumentor().instrument()
```

Si el trace sigue cortándose, suele ser por una de estas razones (en orden de frecuencia):

1. **El propagator global no está configurado** (OTel 1.x usa W3C por default, pero una config `OTEL_PROPAGATORS=b3` lo cambia; verifica env vars).
2. **La instrumentation del cliente no está instalada o no está activa** (p. ej. instrumentaste `requests` pero el código usa `aiohttp`).
3. **Un middleware intermedio reconstruye los headers** y pierde `traceparent` (API gateway custom, service mesh con rewrite, lambda layer, …).

## 5. gRPC: metadata como carrier

En gRPC, lo que en HTTP son headers se llaman **metadata**. La forma del propagator es idéntica: `inject(metadata)` en el cliente, `extract(metadata)` en el servidor. Las instrumentations oficiales (`opentelemetry-instrumentation-grpc`) lo hacen por ti.

La única diferencia operativa es que los nombres de las keys de metadata en gRPC son **lowercase** por convención; `traceparent` cumple.

## 6. Mensajería: Kafka, SQS, RabbitMQ

Las colas son el caso más complicado porque:

- El productor y el consumidor están **desacoplados en el tiempo**. El span del productor típicamente ya está cerrado cuando el consumidor procesa el mensaje.
- La relación semántica no es "parent → child" directo sino **link** (`span.add_link(producer_span_context)`): modela "este span fue causado por aquél, no está contenido en él".

**Kafka** tiene headers por mensaje desde 0.11. El patrón es:

```python
# productor
with tracer.start_as_current_span("publish order", kind=SpanKind.PRODUCER) as span:
    headers = []
    carrier = {}
    inject(carrier)
    headers = [(k, v.encode()) for k, v in carrier.items()]
    producer.send("orders", value=payload, headers=headers)

# consumidor
for msg in consumer:
    carrier = {k: v.decode() for k, v in (msg.headers or [])}
    ctx = extract(carrier)
    with tracer.start_as_current_span("process order", context=ctx, kind=SpanKind.CONSUMER):
        ...
```

**SQS/SNS** usan `MessageAttributes`. La instrumentation `opentelemetry-instrumentation-botocore` lo hace automáticamente. OJO con el límite de 10 attributes por mensaje — si ya los usas, el carrier compite.

**RabbitMQ** usa headers del mensaje AMQP.

## 7. Procesos batch y desacoplados: carriers "fuera de banda"

¿Y si el "hop" no es un transporte en vivo sino un archivo S3 que un job batch leerá mañana? Las opciones:

- **Columna en DB**: cuando enqueuea un job, guarda `traceparent` en una columna. El worker la lee y hace `extract` sobre un dict `{"traceparent": row["traceparent"]}`.
- **Metadata de objeto S3**: `s3.put_object(Metadata={"traceparent": tp})`. El reader la lee del head object.
- **Filename**: menos limpio, válido para scripts puntuales (`report-<trace-id>.csv`).
- **Variable de entorno**: para procesos hijos lanzados vía `subprocess`.

El principio es siempre el mismo: un carrier (texto) que podamos `inject`/`extract`.

## 8. Async en Python: ContextVars y asyncio

`asyncio` conserva el context automáticamente a través de `await`. Cuando creas una task con `asyncio.create_task(coro)`, Python **copia** el context en el momento de la creación (`contextvars.copy_context()` por detrás). Por eso un span abierto antes del `await` sigue siendo "current" después.

Lo que **no** sobrevive es:

- `asyncio.run_in_executor(None, func)` — ejecuta `func` en un `ThreadPoolExecutor` que **no** copia el context. El span padre se pierde.
- `loop.call_later(delay, callback)` — igual.
- Cualquier callback invocado desde una librería que no sea asyncio-aware.

## 9. Thread-local y executors: el gotcha más común

El bug que todo el mundo encuentra:

```python
# ROTO: el worker arranca sin context, su span será root
with tracer.start_as_current_span("parent"):
    executor.submit(do_work)   # do_work no ve "parent" como current
```

Las dos soluciones canónicas:

```python
# Opción A: copiar el context del hilo llamador
import contextvars
ctx = contextvars.copy_context()
executor.submit(ctx.run, do_work)

# Opción B: capturar y attachar explícitamente dentro del worker (OTel)
from opentelemetry.context import attach, detach, get_current
captured = get_current()
def wrapper():
    token = attach(captured)
    try:
        do_work()
    finally:
        detach(token)
executor.submit(wrapper)
```

Para `concurrent.futures.ThreadPoolExecutor`, Python 3.14+ trae `initializer=copy_context().run` como atajo, pero el patrón explícito es portable.

## 10. Errores comunes y cómo diagnosticarlos

| Síntoma | Causa probable | Fix |
|---|---|---|
| Dos traces, cada uno con un servicio | `extract` nunca se llamó en el receptor | Instalar/activar la instrumentation server-side o `extract(headers)` manual. |
| `traceparent` presente en logs del cliente pero el servidor no lo ve | Middleware/proxy que reescribe headers; nombres case-insensitive quebrados | Verificar en el servidor que `request.headers.get("traceparent")` existe. |
| Trace completo en dev, roto en prod | `OTEL_PROPAGATORS` distinto en prod (p. ej. `b3single`) | Alinear propagators cross-service. |
| El worker thread emite spans root | Context no copiado al executor | `copy_context().run(...)` o `attach/detach`. |
| Logs sin `trace_id` cuando debería haberlo | El handler corre fuera del `with span` (background task, atexit) | Mover el log dentro del scope del span o capturar el context. |
| gRPC produce dos traces | Instrumentation gRPC no activa en el server | Verificar `GrpcInstrumentorServer().instrument()` antes de arrancar el server. |

Herramienta diagnóstica #1: `ConsoleSpanExporter` o un collector con `debug` exporter — imprime cada span con su `trace_id` y `parent_id`. Si en el servicio B el `parent_id` sale como ceros, no hubo `extract`.

## 11. Propagators configurables

Por default OTel compone `tracecontext + baggage`. Para interoperar con sistemas legacy:

```bash
# W3C + baggage (default)
OTEL_PROPAGATORS=tracecontext,baggage

# Solo B3 single header (Zipkin, Istio pre-1.11)
OTEL_PROPAGATORS=b3

# Jaeger propagator
OTEL_PROPAGATORS=jaeger,baggage
```

En código:

```python
from opentelemetry.propagate import set_global_textmap
from opentelemetry.propagators.composite import CompositePropagator
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator
from opentelemetry.baggage.propagation import W3CBaggagePropagator

set_global_textmap(CompositePropagator([
    TraceContextTextMapPropagator(),
    W3CBaggagePropagator(),
]))
```

Regla de equipo: **todos los servicios deben usar los mismos propagators**. Esa alineación suele ser el 90% del esfuerzo de "estandarizar observabilidad".

## 12. Mental model final

Pensar la propagación como un **relevo de testigo**:

1. El servicio A abre un span (toma el testigo).
2. Antes de un hop, `inject(carrier)` → el testigo se copia en el carrier.
3. El transporte lleva el carrier.
4. El servicio B hace `extract(carrier)` → reconstruye un parent "fantasma" sin el span real, solo con los IDs.
5. B abre su propio span como hijo de ese parent reconstruido.

Si falla cualquiera de los 5 pasos — el trace se corta. Diagnosticar es revisar cada paso en orden. Esta disciplina, replicada en HTTP, gRPC, Kafka, batch y async, es lo que permite que **un trace end-to-end** cuente la historia completa de una request a través de un sistema distribuido.
