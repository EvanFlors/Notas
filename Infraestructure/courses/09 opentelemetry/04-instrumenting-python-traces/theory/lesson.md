# Lección: Instrumenting Python Traces

> **ID:** `otel-04-instrumenting-python-traces` · **Nivel:** intermedio · **Duración:** 4 h
> **Prerrequisitos:** `otel-03-api-sdk-and-instrumentation-strategies`.

---

## 1. Introducción intuitiva

Instrumentar un servicio Python con OpenTelemetry es equivalente, para traces, a lo que `prometheus_client` hace para métricas: convertir cada operación relevante en una señal observable. La diferencia es que un trace no es un contador agregado — es un **registro causal** con padre/hijo que, en producción, te dice "esta petición HTTP tardó 2 s porque el `checkout.process` esperó 1.8 s a `payment.charge` que esperó 1.6 s a la API externa de pagos". Esa cadena no la reconstruye ninguna métrica.

El flujo en Python es siempre el mismo:

1. Instalas el **SDK** y, opcionalmente, **instrumentation packages** por framework.
2. En `main()` (o en un `otel_setup.py` importado antes que cualquier otro módulo con rutas) configuras un **TracerProvider** con una **Resource** (quién eres), le enchufas uno o más **SpanProcessor** (típicamente **BatchSpanProcessor**) y un **Exporter** (**OTLP** a Collector, o **Console** mientras desarrollas).
3. Obtienes un **tracer** por módulo (`tracer = trace.get_tracer(__name__)`) y creas spans con `tracer.start_as_current_span("operation.name")`.
4. Añades atributos (`span.set_attribute`), eventos (`span.add_event`) y, si hay fallos, `span.record_exception()` + `span.set_status(StatusCode.ERROR)`.

Lo que diferencia una instrumentación "ruidosa" (muchos spans, poca señal, caro) de una "limpia" (los spans que importan al negocio, con atributos útiles, kinds correctos) es exactamente el mismo tipo de disciplina que ya practicaste con métricas: antes de añadir un span, pregúntate si cuenta una **historia operativa** nueva o si solo infla costos.

---

## 2. Paquetes y setup del SDK

### 2.1 Instalación

```bash
pip install \
  opentelemetry-api \
  opentelemetry-sdk \
  opentelemetry-exporter-otlp \
  opentelemetry-instrumentation-fastapi \
  opentelemetry-instrumentation-httpx \
  opentelemetry-instrumentation-requests
```

- `opentelemetry-api` — la que tu *código* importa. Ligera, estable, sin side effects.
- `opentelemetry-sdk` — la implementación. Se inicializa **una vez** en `main()`.
- `opentelemetry-exporter-otlp` — exporter OTLP (gRPC por default; `-http` para HTTP/protobuf).
- `opentelemetry-instrumentation-<lib>` — community packages que envuelven un framework/driver y emiten spans sin que escribas nada.

> **Regla:** la API nunca falla si el SDK no está inicializado; devuelve un tracer "no-op" que no emite nada. Esto permite que **librerías de terceros** importen `opentelemetry.trace` sin forzar un SDK.

### 2.2 TracerProvider, Resource y pipeline

```python
# otel_setup.py — importar ANTES de crear la app
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter


def configure_tracing(service_name: str = "capstone-items") -> TracerProvider:
    resource = Resource.create({
        "service.name": service_name,
        "service.version": "0.1.0",
        "deployment.environment": "dev",
    })
    provider = TracerProvider(resource=resource)
    exporter = OTLPSpanExporter(endpoint="http://localhost:4317", insecure=True)
    provider.add_span_processor(BatchSpanProcessor(exporter))
    trace.set_tracer_provider(provider)
    return provider
```

Puntos a interiorizar:

- La **Resource** viaja con *cada* span. `service.name` es el atributo más importante — el backend particiona por él.
- `BatchSpanProcessor` acumula spans y los flush-ea periódicamente. Un `SimpleSpanProcessor` los exporta uno a uno (útil solo en tests).
- `OTLPSpanExporter` (gRPC) → `:4317`. Si usas el exporter HTTP (`opentelemetry.exporter.otlp.proto.http`), apunta a `:4318/v1/traces`.
- Llama `provider.shutdown()` en el shutdown hook de la app para no perder el último batch.

### 2.3 Fallback a consola sin Collector

Cuando no tienes un Collector arriba (desarrollo, demos, tests), cambia el exporter:

```python
from opentelemetry.sdk.trace.export import ConsoleSpanExporter
provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
```

Imprime cada span como JSON a stdout. **No** uses esto en producción: cada span va al log, y el log se multiplica.

---

## 3. El CLI `opentelemetry-instrument` (zero-code)

El paquete `opentelemetry-distro` (meta-package con SDK + autoconfig) instala un CLI:

```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install      # auto-detecta e instala instrumentations
opentelemetry-instrument \
  --service_name capstone-items \
  --exporter_otlp_endpoint http://localhost:4317 \
  python -m uvicorn app:app --port 8000
```

Lo que hace por debajo:

- Carga el `autoinstrumentation` sitecustomize que registra todas las `opentelemetry-instrumentation-*` presentes.
- Lee variables de entorno `OTEL_*` (`OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_TRACES_SAMPLER`, `OTEL_RESOURCE_ATTRIBUTES`).
- Configura un TracerProvider por default.

**Cuándo usarlo**: visibilidad inicial sin tocar código. **Cuándo no**: cuando necesitas control fino (varios exporters, SpanProcessors custom, filtrado) — ahí vuelves al setup programático de §2.

Las dos vías **conviven**: puedes usar `opentelemetry-instrument` *y* además crear spans manuales con `trace.get_tracer()`. Los manuales se enchufan al TracerProvider que el CLI ya creó.

---

## 4. Instrumentation libraries

```python
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

FastAPIInstrumentor.instrument_app(app)      # spans SERVER por request
HTTPXClientInstrumentor().instrument()       # spans CLIENT por cada httpx.get
RequestsInstrumentor().instrument()          # idem con requests.*
```

Cada librería emite spans con **semconv HTTP** vigente: `http.request.method`, `http.response.status_code`, `url.full`, `server.address`, `server.port`, `http.route` (templatizado). No tienes que inventar nada — y lo más importante, otros servicios en otros lenguajes emiten *los mismos atributos* porque también siguen semconv.

Lista corta de instrumentations que querrás casi siempre:
- Framework HTTP: `fastapi`, `starlette`, `flask`, `django`.
- Clientes HTTP: `httpx`, `requests`, `urllib3`.
- DB: `psycopg` (Postgres), `pymongo`, `sqlalchemy`.
- Cache/queue: `redis`, `kafka-python`, `pika` (RabbitMQ).
- Logging bridge: `logging` (se cubre en `otel-06`).

---

## 5. Spans manuales con `start_as_current_span`

```python
from opentelemetry import trace
tracer = trace.get_tracer(__name__)

def process_checkout(cart_id: str, user_id: str, total_cents: int) -> str:
    with tracer.start_as_current_span("checkout.process") as span:
        span.set_attribute("checkout.cart_id", cart_id)
        span.set_attribute("checkout.total_cents", total_cents)
        span.set_attribute("enduser.id", user_id)   # semconv
        reserve_inventory(cart_id)
        payment_id = charge_payment(user_id, total_cents)
        span.set_attribute("checkout.payment_id", payment_id)
        return payment_id
```

Puntos clave:

- `start_as_current_span` **empuja** el span al Context actual (contextvars). Cualquier span creado *dentro* del `with` tiene a este como padre, automáticamente.
- Si usas `tracer.start_span("x")` sin `as current`, obtienes un span **huérfano**: no se adhiere al Context, nada que se cree debajo lo verá como padre. Es casi siempre un bug.
- El `with` cierra el span al salir, incluso con excepción — pero no cambia status salvo que lo hagas explícito (ver §8).

### 5.1 Nested y parent/child

```python
def charge_payment(user_id: str, cents: int) -> str:
    with tracer.start_as_current_span("payment.charge") as span:
        span.set_attribute("payment.user_id", user_id)
        span.set_attribute("payment.amount_cents", cents)
        # El span creado por httpx (si está instrumentado) tendrá payment.charge como padre.
        resp = httpx.post("https://pay.example.com/v1/charge", json={...})
        resp.raise_for_status()
        return resp.json()["id"]
```

En el trace final verás: `HTTP POST /checkout` (SERVER) → `checkout.process` (INTERNAL) → `payment.charge` (INTERNAL) → `POST pay.example.com` (CLIENT). Esa jerarquía te dice *dónde* se gastó cada ms.

---

## 6. Atributos: `set_attribute`

```python
span.set_attribute("checkout.items.count", len(cart.items))
span.set_attribute("checkout.cart_id", cart.id)
span.set_attribute("payment.method", "stripe")      # bounded cardinality
span.set_attribute("db.statement", redacted_sql)    # cuidado con PII
```

Reglas:

- **Nombres jerárquicos con `.`**: `payment.method`, no `paymentMethod`.
- **Semconv primero**: `http.*`, `db.*`, `messaging.*`, `enduser.*`, `error.*` ya están definidos — úsalos antes de inventar los tuyos.
- **Namespace propio** cuando no haya semconv: `checkout.*`, `inventory.*` (tu dominio).
- **Valores**: str, bool, int, float, o secuencia homogénea. No dicts anidados.
- **Costo**: cada atributo se serializa en el export. Strings largos (payloads completos, stack traces inline fuera de `record_exception`) multiplican el bytes-per-span → coste de egress y almacenamiento en el backend.
- **Cardinalidad en atributos** importa menos que en métricas (traces no se agregan por label), pero **no metas PII** (`enduser.email`, cookies, tokens): los traces persisten en Tempo/Jaeger meses.

Un atributo por request con un UUID (`request_id`) está bien. Un atributo con el body JSON completo del request, no.

---

## 7. Eventos: `add_event`

Un **evento** es un timestamp con nombre dentro de un span. Útil para marcar hitos sin crear un sub-span:

```python
with tracer.start_as_current_span("checkout.process") as span:
    span.add_event("inventory.reserved", {"items.count": 3})
    span.add_event("fraud.check.passed", {"risk.score": 0.12})
    span.add_event("payment.initiated")
```

Cuándo evento vs cuándo span:
- **Evento** — algo instantáneo, no mide duración, da contexto.
- **Span** — algo con duración, puede fallar independiente, suele tener hijos.

Si lo que marcas tiene inicio y fin con posible fallo propio, es span.

---

## 8. Status: `set_status` y `record_exception`

Por default, un span cerrado tiene status **UNSET** (no se asume éxito). El backend lo renderiza neutro. Para marcar error explícitamente:

```python
from opentelemetry.trace import Status, StatusCode

try:
    resp = httpx.post(url, json=body, timeout=5)
    resp.raise_for_status()
except Exception as exc:
    span.record_exception(exc)
    span.set_status(Status(StatusCode.ERROR, description=str(exc)))
    raise
```

- `record_exception(exc)` crea un evento `exception` con atributos semconv (`exception.type`, `exception.message`, `exception.stacktrace`). **No cambia** el status.
- `set_status(StatusCode.ERROR, ...)` sí lo marca. Si no lo haces, el backend pintará el span como "ok" aunque haya una excepción adjunta.
- `StatusCode.OK` existe pero rara vez se usa — el default UNSET ya significa "no se marcó error".

**Caveat de `with ...:`**: el `start_as_current_span` por default *no* graba la excepción ni marca error si una excepción se escapa del bloque. Si quieres ese comportamiento automático:

```python
with tracer.start_as_current_span(
    "checkout.process",
    record_exception=True,       # añade el evento
    set_status_on_exception=True # marca StatusCode.ERROR
) as span:
    ...
```

Es un buen default para spans de operaciones de negocio.

---

## 9. Span kinds

Cada span tiene un **kind** que describe su rol en la comunicación:

| Kind | Significado | Ejemplo típico |
|------|-------------|----------------|
| `SERVER` | Procesando una request entrante | handler HTTP, gRPC server, consumer HTTP |
| `CLIENT` | Haciendo una request saliente | `httpx.post(...)`, `psycopg.execute(...)` |
| `PRODUCER` | Encolando un mensaje | `kafka.send(...)`, SQS `send_message` |
| `CONSUMER` | Consumiendo de una cola | handler Kafka/SQS |
| `INTERNAL` (default) | Trabajo in-process | `checkout.process`, `fraud.check` |

```python
from opentelemetry.trace import SpanKind
with tracer.start_as_current_span("send.order.event", kind=SpanKind.PRODUCER) as span:
    kafka.produce("orders", payload)
```

Las instrumentations community ya ponen el kind correcto (fastapi → SERVER, httpx → CLIENT). Para spans manuales, el default `INTERNAL` suele ser el adecuado; cambia solo si el span cruza un boundary de red o cola.

---

## 10. Nombres: por operación de negocio, no por método HTTP

Un error extendido: nombrar spans manuales como `POST /pay` o `handle_checkout_request`. Esos nombres replican lo que la instrumentation HTTP ya aporta y pierden información de dominio.

**Mal**:
```
POST /pay
  └─ handle_pay_request
      └─ POST /pay           ← duplicado del root
          └─ db_query_1
```

**Bien**:
```
POST /pay                    ← auto (SERVER)
  └─ checkout.process        ← manual (INTERNAL)
      ├─ inventory.reserve   ← manual
      ├─ fraud.check         ← manual
      └─ payment.charge      ← manual
          └─ POST pay.stripe.com   ← auto (CLIENT)
```

Convención práctica:

- `<dominio>.<verbo>` o `<dominio>.<verbo>.<sub>`.
- Minúsculas con puntos: `checkout.process`, `inventory.reserve`, `payment.charge`, `email.send.welcome`.
- Nombre **estable** entre deploys — igual que una métrica, un span name es un contrato para dashboards y alertas basadas en traces (TraceQL en Tempo, por ejemplo).
- No metas identificadores en el nombre: `checkout.process` nunca `checkout.process.cart-123` (eso es un atributo).

---

## 11. Context, async y threads

Python propaga el Context vía `contextvars`, que **sí** cruza `await`. Esto significa que spans creados dentro de corrutinas tienen el padre correcto automáticamente.

Lo que **no** cruza:

- `concurrent.futures.ThreadPoolExecutor.submit(fn, ...)` — el thread arrancado no ve el Context del caller.
- `multiprocessing` — proceso nuevo, cero Context.

Para threads hay un helper:

```python
from opentelemetry.context import attach, detach, get_current
ctx = get_current()
def worker():
    token = attach(ctx)
    try:
        with tracer.start_as_current_span("background.work") as span:
            ...
    finally:
        detach(token)
```

O usa `contextvars.copy_context().run(worker)`. El módulo `otel-07` cubre esto en detalle (incluyendo propagación cross-service con `inject`/`extract`).

---

## 12. Operaciones y antipatterns

**No doble-instrumentes el mismo tramo.** Si `fastapi` ya emite el span SERVER, no añadas uno manual que envuelve `call_next`. Suma coste, no señal.

**No pongas PII como atributo.** `enduser.email`, cookies, bodies con tarjetas: todo eso queda en el backend. Usa IDs opacos.

**No olvides `shutdown()`.** Un crash brutal del proceso pierde el batch pendiente del `BatchSpanProcessor`. Registra un shutdown hook (FastAPI: `@app.on_event("shutdown")` o lifespan context manager).

**No uses `start_span` cuando quieres `start_as_current_span`.** Spans huérfanos son el síntoma típico: ves spans sueltos en el backend sin padre esperado.

**No crees un tracer global**: `trace.get_tracer(__name__)` es barato y el nombre del tracer aparece en el backend — útil para filtrar por módulo.

**No instrumentes bucles tight.** Un `for item in 10_000_items: with tracer.start_as_current_span("item.process")` crea 10 k spans por request y agota el BatchSpanProcessor queue. Agrupa: un span para el lote con `batch.size` como atributo, eventos para hitos.

**Sampling es responsabilidad del Collector o del provider.** Head-based (`ParentBased(TraceIdRatioBased(0.1))`) va en el `TracerProvider`; tail-based va en el Collector. Ambos se cubren en `otel-10`. Para dev, sampleo 100%.

**No logs de "span creado"**. Si quieres saber si la instrumentación funciona, usa `ConsoleSpanExporter` temporalmente — es *el* debug de OTel. No añadas prints alrededor.

Con esto cierras el ciclo del tracing in-process: provider con resource → batch → exporter → tracer por módulo → spans con nombres de dominio, kinds, atributos semconv, eventos y status → shutdown limpio. En `otel-05` lo repites para métricas, en `otel-06` para logs; en `otel-07` propagas el trace entre servicios; en `otel-10` decides qué muestras de todo esto llegan al backend.
