# Lección — API, SDK y estrategias de instrumentación

> Módulo `otel-03`. Objetivo: distinguir con precisión los tres bloques que componen "instrumentar con OTel" y las cuatro familias de instrumentación (manual, library, auto, zero-code eBPF).

---

## 1. Mapa mental: tres cajas, una línea

Antes de cualquier código, interioriza esta imagen:

```
   tu código ──► API (interface) ──► SDK (impl) ──► Exporter ──► Collector / Backend
                    │                   │
                    │                   └── providers, processors, sampling, batching
                    │
                    └── get_tracer, start_as_current_span, set_attribute
```

Tres **artefactos distintos** empaquetados en **tres paquetes PyPI distintos**:

| Caja | Paquete Python | Lo importa… | Se instala en… |
|------|-----------------|-------------|-----------------|
| API | `opentelemetry-api` | tu código de dominio **y** las libraries de instrumentación | siempre |
| SDK | `opentelemetry-sdk` | **solo** el `main()` de la app | solo en la app, no en libraries publicables |
| Exporter | `opentelemetry-exporter-otlp` (u otro) | `main()` de la app | solo en la app |

La **regla de oro** de OTel: *tu librería publicable depende solo de la API; nunca del SDK*. Así, quien la consume elige su SDK (o ninguno) sin fricción.

---

## 2. La API: una interfaz no-op por default

```python
# código de dominio: solo usa la API
from opentelemetry import trace

tracer = trace.get_tracer("mi.servicio")

def apply_coupon(cart_id: str, code: str) -> int:
    with tracer.start_as_current_span("apply_coupon") as span:
        span.set_attribute("cart.id", cart_id)
        span.set_attribute("coupon.code", code)
        return _discount_cents(code)
```

Si en el proceso **no se registra un SDK**, `get_tracer()` devuelve un **tracer no-op**: `start_as_current_span` es un objeto placeholder, `set_attribute` no hace nada, no se emite telemetría y **no hay error**. Esto es intencional: una library puede emitir spans sin obligar a nada al consumidor.

> **Consecuencia práctica:** si "no te aparecen spans", el primer diagnóstico es "¿se registró el SDK antes de que corriera el código?".

---

## 3. El SDK: configuración única en `main()`

El SDK aporta las clases concretas: `TracerProvider`, `SpanProcessor`, `Sampler`, `Resource`, `*Exporter`. Se ensambla una sola vez al arrancar.

```python
# main.py
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter

resource = Resource.create({
    "service.name": "checkout",
    "service.version": "1.4.0",
    "deployment.environment": "dev",
})

provider = TracerProvider(resource=resource)
provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
trace.set_tracer_provider(provider)

# a partir de aquí, cualquier get_tracer() ya es "real"
```

Puntos a interiorizar:

- **`set_tracer_provider` solo surte efecto una vez.** Un segundo registro se ignora (silenciosamente) — gotcha clásico en tests.
- **`BatchSpanProcessor`** acumula spans en memoria y los envía por lotes; en dev suele usarse `SimpleSpanProcessor` para ver spans de inmediato.
- El **`Resource`** se adjunta a *todos* los spans del proceso. Es donde van los atributos del productor (semconv del curso `otel-02`).

---

## 4. Instrumentation libraries: cubrir frameworks sin tocar código

Un **instrumentation library** es un paquete community que sabe cómo instrumentar un framework o driver concreto, abriendo y cerrando spans en los puntos semánticamente correctos.

| Paquete | Qué envuelve | Qué emite típicamente |
|---------|---------------|------------------------|
| `opentelemetry-instrumentation-fastapi` | FastAPI | 1 span SERVER por request con `http.*` |
| `opentelemetry-instrumentation-requests` | `requests` | 1 span CLIENT por llamada HTTP outbound |
| `opentelemetry-instrumentation-httpx` | `httpx` | idem para httpx (sync y async) |
| `opentelemetry-instrumentation-psycopg2` | psycopg2 | 1 span CLIENT por query con `db.statement` |
| `opentelemetry-instrumentation-redis` | redis-py | 1 span CLIENT por comando |
| `opentelemetry-instrumentation-logging` | `logging` stdlib | inyecta `trace_id`/`span_id` en cada record |

Dos formas de usarlos:

1. **Manual**: tú llamas `FastAPIInstrumentor.instrument_app(app)` desde el `main()`.
2. **Vía `opentelemetry-instrument`**: el CLI descubre los instrumentors por entry points y los inicializa por ti (siguiente sección).

---

## 5. Auto-instrumentation con `opentelemetry-instrument`

El paquete `opentelemetry-distro` + `opentelemetry-instrumentation` instala el CLI `opentelemetry-instrument`. Se usa así:

```bash
opentelemetry-instrument \
  --traces_exporter=console \
  --metrics_exporter=console \
  --logs_exporter=console \
  --service_name=checkout \
  uvicorn app:app --host 0.0.0.0 --port 8000
```

Qué pasa dentro, en orden:

1. El CLI configura un SDK por default (TracerProvider, MeterProvider, LoggerProvider) con los exporters indicados.
2. Lee todos los paquetes `opentelemetry-instrumentation-*` instalados y los activa.
3. Hace `exec` del comando que le pasaste (`uvicorn ...`).
4. Cuando tu app importa FastAPI, el instrumentor FastAPI ya está activo — se enganchará a `app`.

> **Variables de entorno** equivalentes: `OTEL_SERVICE_NAME`, `OTEL_TRACES_EXPORTER`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_RESOURCE_ATTRIBUTES=team=checkout,deployment.environment=dev`. En Kubernetes casi siempre se configura por env, no por flags.

Lo que **no** hace auto:

- No crea spans en tu lógica de dominio (no sabe qué es "aplicar cupón").
- No añade atributos de negocio (`cart.total_cents`, `coupon.code`).
- No marca errores de dominio como `status=ERROR` si tu código los convierte en `HTTP 200` con un `{"ok": false}`.

Para eso están los **spans manuales** sobre la API (sección 2).

---

## 6. Las cuatro familias de instrumentación

| Familia | Qué toca | Esfuerzo | Semántica de negocio | Ejemplo |
|---------|----------|----------|----------------------|---------|
| **Manual** | tu código | alto | sí (tú defines) | `with tracer.start_as_current_span("apply_coupon")` |
| **Instrumentation library (explícita)** | librería/framework | medio-bajo | solo técnica | `FastAPIInstrumentor.instrument_app(app)` |
| **Auto-instrumentation (CLI)** | ambos (import time) | mínimo | solo técnica | `opentelemetry-instrument uvicorn ...` |
| **Zero-code (eBPF/sidecar)** | fuera del proceso | mínimo | solo de red/syscall | Pixie, Grafana Beyla |

Las cuatro **no son mutuamente excluyentes**: el patrón recomendado para una app nueva es **auto + manual**: la CLI te da RED y clientes HTTP/DB "gratis" y tú añades los 3–10 spans de dominio que importan.

---

## 7. Zero-code eBPF: Pixie, Beyla y amigos

**eBPF** (extended Berkeley Packet Filter) permite ejecutar programas sanitizados en el kernel que observan syscalls, tráfico de red, uprobes, etc., **sin modificar la aplicación**. Sobre eso se construyen:

- **Grafana Beyla** — genera spans y RED metrics viendo HTTP/HTTPS/gRPC en kernel, los envía como OTLP. Ideal para dar visibilidad a servicios que *no puedes* o *no quieres* tocar (binario Go sin fuente, legacy en C++).
- **Pixie** (Autodidata/New Relic) — observabilidad completa en Kubernetes vía eBPF, DataFrames para query sobre el stream en vivo.
- **Hubble** (Cilium) — más orientado a networking L3/L4/L7, pero útil para red.

Ventajas:

- Cero cambios al código, cero reinicio con flags, cero paquetes añadidos.
- Cobertura instantánea de **todo** el nodo o cluster.

Limitaciones serias:

- **No ve intent de negocio**: no distingue "aplicar cupón" de "listar productos" si ambos caen al mismo endpoint `/api/v1/do`.
- **No ve TLS internamente** salvo que uses uprobes sobre OpenSSL (frágil cross-versiones).
- Requiere **permisos privilegiados** (CAP_BPF, CAP_PERFMON, a menudo `hostPID`) — barrera en entornos restrictivos.
- No sustituye spans manuales de dominio, los *complementa* en el perímetro.

Regla: **eBPF primero** si no puedes instrumentar el código (binario cerrado, idioma sin SDK maduro); **SDK + auto** en todo lo que sí puedas tocar.

---

## 8. Manual vs auto: cuándo cada uno

Lista de disparadores para abrir un span manual aunque auto ya cubra la ruta:

- **Operación de dominio** con nombre propio ("reservar inventario", "cobrar tarjeta").
- **Loop o batch** interno que domina la latencia y no está instrumentado por una library.
- **Transacción cross-recurso** (varios HTTP + DB) donde quieres un *parent* legible, no una lista plana.
- **Error de dominio** que no es excepción Python ni HTTP 5xx (p. ej., stock insuficiente devuelto como 200).

Lista de disparadores para **no** añadir manual:

- Ya hay un span idéntico generado por la library (duplicarías).
- El span dura microsegundos y no aporta información (ruido puro).
- El atributo que ibas a añadir tiene cardinalidad alta (user id, request id, email).

---

## 9. Qué pasa en import time: por qué el orden importa

El modelo mental para `opentelemetry-instrument`:

```
proceso arranca
  └── opentelemetry-instrument detecta entry points
       └── llama a cada *Instrumentor().instrument() ANTES de que corra tu app
            └── los Instrumentor hacen monkey-patch de módulos clave
                 └── exec(uvicorn ...)
                      └── tu app importa fastapi → ya está parcheado
                           └── primera request → spans fluyen
```

Si **tu app** llama `trace.set_tracer_provider(...)` **después** de la CLI, el provider de la CLI se mantiene (recordatorio: el primer set gana). Esto es correcto 95% del tiempo — para evitar sorpresas, usa env vars (`OTEL_SERVICE_NAME`, etc.) en lugar de setear SDK a mano cuando corres con el CLI.

---

## 10. Diseño de la cobertura por servicio

Al diseñar observabilidad para un sistema, llena una **matriz** antes de instrumentar:

| Servicio | Lenguaje | Framework | Auto cubre | Manual necesario | eBPF considerado | Decisión |
|----------|----------|-----------|-------------|-------------------|------------------|----------|
| checkout-api | Python 3.12 | FastAPI | http+psycopg2+redis | 3 spans (coupon, inventory, charge) | no | auto + manual |
| worker-emails | Python 3.12 | celery | celery tasks | 1 span por template render | no | auto + manual |
| legacy-pricing | Go 1.17 | net/http propio | — (sin SDK fácil) | — | sí (Beyla) | eBPF |
| scheduler | cron bash | — | — | — | sí (Beyla a nivel nodo) | eBPF o nada |

Este tipo de matriz es un **entregable** del módulo y guía las decisiones de los módulos siguientes (`otel-04` en adelante).

---

## 11. Pitfalls comunes del día uno

- **Importas la API, no registras SDK → no ves spans** y no hay error. Diagnóstico: añade un `ConsoleSpanExporter` temporal.
- **Duplicas spans**: activaste la instrumentation library manualmente *y* corres con `opentelemetry-instrument`. Elige uno.
- **Spans "huérfanos"**: usaste `tracer.start_span(...)` en lugar de `start_as_current_span(...)` — el span abierto no se adhirió al context, por lo que spans hijos arrancan sin parent.
- **Attributes caros**: añades `span.set_attribute("request.body", json.dumps(payload))` — bomba de cardinalidad y de bytes. Mantén atributos cortos, finitos y útiles.
- **Setear el provider dos veces** (típico cuando un test crea un segundo SDK): el segundo se ignora, los nuevos spans van al primero. Resetea providers entre tests si lo necesitas.
- **`opentelemetry-instrument` + process managers**: con `gunicorn`, cada worker es un proceso hijo. Asegúrate de que `opentelemetry-instrument` envuelve a `gunicorn`, no a `gunicorn` quien lanza workers de otra forma.

---

## 12. Checklist de salida del módulo

Marca cada ítem antes de pasar a `otel-04`:

- [ ] Puedo explicar la diferencia entre `opentelemetry-api` y `opentelemetry-sdk` sin mirar notas.
- [ ] Sé qué devuelve `trace.get_tracer()` si no hay SDK registrado.
- [ ] He corrido `opentelemetry-instrument uvicorn app:app` y he visto spans en consola.
- [ ] He añadido manualmente un span con `start_as_current_span` y un `set_attribute`.
- [ ] Puedo nombrar al menos 3 `opentelemetry-instrumentation-*` paquetes y qué cubre cada uno.
- [ ] Puedo defender cuándo prefiero eBPF (Beyla/Pixie) a instrumentación en código.
- [ ] He producido una matriz "servicio × estrategia" para 4 servicios con decisión justificada.
- [ ] Sé por qué duplicar la instrumentation (CLI + manual del mismo library) genera spans duplicados.
