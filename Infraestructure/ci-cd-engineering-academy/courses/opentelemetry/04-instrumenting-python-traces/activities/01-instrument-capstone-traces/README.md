# otel-04-01 — Instrument capstone with OTel traces (guided-lab)

## 1. Identificación
- **ID:** `otel-04-01-instrument-capstone-traces`
- **Tecnología:** opentelemetry
- **Módulo:** 04-instrumenting-python-traces
- **Dificultad:** intermediate
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto

Recibes `starter/app.py`: una app FastAPI del capstone con un endpoint `POST /checkout` que llama a dos funciones (`reserve_inventory`, `charge_payment`). No tiene **nada** de OTel. Tu tarea: inicializar el SDK, exportar spans (consola si no hay Collector; OTLP si `OTEL_EXPORTER_OTLP_ENDPOINT` está seteado) y añadir **spans manuales** para las operaciones de negocio con atributos y status.

## 3. Objetivos

- Configurar `TracerProvider` + `Resource` (`service.name=capstone-checkout`) + `BatchSpanProcessor` + exporter (console por default, OTLP opcional).
- Obtener un tracer por módulo con `trace.get_tracer(__name__)`.
- Crear tres spans manuales con nombres de dominio: `checkout.process`, `inventory.reserve`, `payment.charge`.
- Añadir atributos (`checkout.cart_id`, `checkout.total_cents`, `payment.method`).
- Marcar `Status(StatusCode.ERROR)` + `record_exception` cuando el pago falla.
- Flush del batch con `provider.shutdown()` en el evento de shutdown de FastAPI.

## 4. Prerrequisitos

- Python 3.10+.
- `pip install fastapi uvicorn opentelemetry-api opentelemetry-sdk`.
- Opcional: `opentelemetry-exporter-otlp` + Collector local escuchando OTLP gRPC en `:4317`.
- Puerto libre (default 8791).
- Coste: 0.

## 5. Instrucciones

1. Lee `starter/app.py`. Fíjate en los comentarios `TODO`.
2. Crea un `otel_setup.py` (o pon la configuración en `app.py` antes de instanciar FastAPI) con:

   ```python
   from opentelemetry import trace
   from opentelemetry.sdk.resources import Resource
   from opentelemetry.sdk.trace import TracerProvider
   from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter

   def configure_tracing():
       provider = TracerProvider(resource=Resource.create({
           "service.name": "capstone-checkout",
           "service.version": "0.1.0",
           "deployment.environment": "dev",
       }))
       # Prefer OTLP if endpoint is set, else fall back to console.
       import os
       if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT"):
           from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
           exporter = OTLPSpanExporter(insecure=True)
       else:
           exporter = ConsoleSpanExporter()
       provider.add_span_processor(BatchSpanProcessor(exporter))
       trace.set_tracer_provider(provider)
       return provider
   ```

3. En `app.py`, llama `configure_tracing()` **antes** de `app = FastAPI(...)` y guarda el provider para shutdown.
4. Obtén `tracer = trace.get_tracer(__name__)` a nivel módulo.
5. Envuelve el handler `POST /checkout` con `with tracer.start_as_current_span("checkout.process") as span:` y añade atributos (`checkout.cart_id`, `checkout.total_cents`, `enduser.id`).
6. Envuelve `reserve_inventory` y `charge_payment` en sus propios spans (`inventory.reserve`, `payment.charge`) con atributos del dominio.
7. En `charge_payment`, cuando `amount_cents > 100000`, lanza `ValueError("amount above limit")`. Antes del raise, `span.record_exception(exc)` + `span.set_status(Status(StatusCode.ERROR, str(exc)))`.
8. Registra un shutdown hook de FastAPI que llame `provider.shutdown()`.
9. Levanta:
   ```bash
   cd starter
   python3 -m uvicorn app:app --port 8791
   ```
10. En otra terminal:
    ```bash
    curl -s -X POST localhost:8791/checkout \
      -H 'content-type: application/json' \
      -d '{"cart_id":"c1","user_id":"u1","items_count":2,"total_cents":4999}'
    curl -s -X POST localhost:8791/checkout \
      -H 'content-type: application/json' \
      -d '{"cart_id":"c2","user_id":"u2","items_count":1,"total_cents":200000}' || true
    ```
11. Observa los spans impresos en la consola de uvicorn.
12. Corre el validador: `bash tests/validate.sh`.

Si te atascas, mira `solution/` al final.

## 6. Resultado esperado

- Consola imprime spans JSON con nombres `checkout.process`, `inventory.reserve`, `payment.charge`.
- El trace del segundo request contiene un `payment.charge` con `status_code=ERROR` y evento `exception` adjunto.
- `service.name=capstone-checkout` aparece en los resource attributes.
- `bash tests/validate.sh` imprime `OK`.

## 7. Criterios de aceptación

- Los tres span names existen y están jerárquicamente anidados (mismo `trace_id`, `parent_id` correcto).
- Atributos de dominio presentes (al menos `checkout.cart_id` y `payment.amount_cents`).
- Al menos un span con `status_code=ERROR` en el caso del límite excedido.
- No se usan nombres HTTP-céntricos (`POST /checkout`) para los spans manuales.

## 8. Validación

```bash
bash tests/validate.sh
```

El validador:
1. SKIP si faltan `fastapi`/`uvicorn`/`opentelemetry-sdk`.
2. Lanza la app con `OTEL_EXPORTER_OTLP_ENDPOINT` **sin setear** (fuerza console exporter).
3. Dispara dos requests (uno OK, uno que supera el límite).
4. Mata la app (shutdown fluushea el batch).
5. Grep del log por los tres span names, el ERROR, y `service.name`.

## 9. Preguntas de reflexión

- ¿Por qué `start_as_current_span` (y no `start_span`) para que la jerarquía quede bien?
- ¿Qué pasa si olvidas `provider.shutdown()`? Pista: `BatchSpanProcessor`.
- ¿Por qué nombrar el span `checkout.process` y no `POST /checkout`?
- ¿Dónde pondrías el `cart_id` si fuera un email del usuario? (Pista: no en traces).
- ¿Cómo cambiaría tu setup si quisieras exportar **tanto** a OTLP como a consola a la vez?

## 10. Extensiones

- Instrumenta `httpx` con `HTTPXClientInstrumentor` y haz una llamada saliente desde `payment.charge` a `http://127.0.0.1:9999/__noop__`; observa el span CLIENT anidado.
- Añade un sampler head-based: `TracerProvider(sampler=ParentBased(TraceIdRatioBased(0.5)))` y repite 10 veces el curl — ~50% de traces desaparecen.
- Levanta un Collector local (`otel/opentelemetry-collector-contrib` en docker) con exporter `debug` y exporta OTLP real.

## 11. Limpieza

```bash
pkill -f "uvicorn app:app --port 8791" 2>/dev/null || true
rm -f /tmp/otel04-01-*
```
