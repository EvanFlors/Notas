# Lección — Logs API y bridges

> 12 secciones. Lee en orden; cada sección cierra con una pregunta de autoevaluación.

---

## 1. Por qué logs vienen al final

Los tres signals de OTel no maduraron a la vez: **traces** primero (2021), **metrics** después (2022), **logs** por último (2023). La razón es histórica y pragmática:

- Casi toda app ya tiene **logging** — stdlib, `log4j`, `slog`, `winston`, `Serilog`. OTel no podía llegar y pedir que se reescribiera.
- El valor diferencial de OTel sobre logs no es "emitir logs" (eso ya se hacía) sino **correlacionarlos** con los otros signals vía `trace_id`.
- El data model había que estandarizarlo *después* de los otros, porque el log OTel se diseña para ser el "contenedor común" del `syslog`, `logback`, `log4j`, `winlog`, etc.

**Idea clave**: en OTel, logs no se trata de un nuevo logging framework. Es una **capa de transporte + semántica** que recoge lo que ya producen los frameworks locales.

> ¿Por qué logs es el signal más joven de OTel?

---

## 2. El `LogRecord` de OTel

Un `LogRecord` OTLP tiene estos campos (resumidos):

| Campo | Tipo | Significado |
|---|---|---|
| `timestamp` | uint64 ns | Cuándo ocurrió el evento. |
| `observed_timestamp` | uint64 ns | Cuándo lo observó el pipeline (útil para `tail -F` de archivos antiguos). |
| `severity_number` | enum 1–24 | Nivel estandarizado (TRACE, DEBUG, INFO, WARN, ERROR, FATAL con sublevels). |
| `severity_text` | string | Lo que diga la fuente (`"INFO"`, `"warning"`, `"W"`, etc.). |
| `body` | any | El mensaje principal (string **o estructurado**: map, array, number…). |
| `attributes` | map<string, any> | Metadata del evento (`user.id`, `http.status_code`). |
| `resource` | map<string, any> | Metadata del **productor** (`service.name`, `k8s.pod.name`) — hereda del `Resource` del SDK. |
| `instrumentation_scope` | `{name, version}` | Qué logger emitió (análogo a `tracer` de un paquete). |
| `trace_id`, `span_id`, `trace_flags` | hex | Correlación con un trace activo. |

Diferencias con el `LogRecord` del stdlib Python:
- stdlib: `levelno/levelname`, `msg`, `args`, `pathname`, `lineno`, `funcName`.
- OTel: `severity_number/severity_text`, `body`, `attributes`, `resource`, `trace_id/span_id`.

El **handler bridge** mapea 1:1: `levelno→severity_number`, `msg%args→body`, `extra→attributes`, info del Resource (globalmente configurado).

> ¿Cuál es la diferencia entre `timestamp` y `observed_timestamp`?

---

## 3. Logs API vs Bridges — qué usar

**Logs API** (uso directo):

```python
from opentelemetry._logs import get_logger_provider
from opentelemetry.sdk._logs import LogRecord
logger = get_logger_provider().get_logger("my.lib", "1.0.0")
logger.emit(LogRecord(body="hola", severity_number=9, severity_text="INFO"))
```

Verboso, invasivo, obliga a reescribir call sites.

**Bridge** (recomendado):

```python
import logging
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.sdk._logs import LoggingHandler

provider = LoggerProvider()
provider.add_log_record_processor(BatchLogRecordProcessor(OTLPLogExporter()))

handler = LoggingHandler(level=logging.INFO, logger_provider=provider)
logging.getLogger().addHandler(handler)

# Y toda tu app sigue usando `logger.info(...)` igual que siempre.
logging.getLogger(__name__).info("servicio arrancado")
```

Regla: **usa bridges en apps**; la Logs API directa queda para librerías específicas que quieren control fino.

> ¿Qué pasaría si tuvieras que reescribir 300 call sites `logger.info` para usar la Logs API directa?

---

## 4. Cómo nace el `trace_id` en un log

Momento clave dentro de `LoggingHandler.emit()`:

```python
span = trace.get_current_span()
ctx = span.get_span_context() if span else None
if ctx and ctx.is_valid:
    record.trace_id = ctx.trace_id
    record.span_id  = ctx.span_id
    record.trace_flags = ctx.trace_flags
```

Es decir: el handler **lee del Context actual** cuál es el span activo. En Python, el Context se guarda en `ContextVars` (async-safe, thread-safe). Si el `logger.info(...)` se ejecuta **dentro** de un `with tracer.start_as_current_span(...)`, hay span y hay correlación. Si fuera del span, no.

Esto significa que la calidad de la correlación depende enteramente de tener los **spans bien propagados** — que es el trabajo de `otel-04` (traces manual/auto) y `otel-07` (cross-service). Logs solo cosecha.

> Si llamas `logger.info()` desde un callback que se ejecuta en otro `ThreadPoolExecutor` sin propagar el context, ¿el log tendrá `trace_id`?

---

## 5. El wiring canónico en Python

```python
import logging
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter

def setup_otel_logging(service_name: str, endpoint: str = "http://localhost:4317") -> LoggerProvider:
    resource = Resource.create({"service.name": service_name, "service.version": "0.1.0"})
    provider = LoggerProvider(resource=resource)
    exporter = OTLPLogExporter(endpoint=endpoint, insecure=True)
    provider.add_log_record_processor(BatchLogRecordProcessor(exporter))

    handler = LoggingHandler(level=logging.INFO, logger_provider=provider)
    root = logging.getLogger()
    root.setLevel(logging.INFO)
    root.addHandler(handler)
    return provider

# en main():
provider = setup_otel_logging("payments-api")
try:
    run_app()
finally:
    provider.shutdown()  # flushea el batch
```

Puntos clave:

- `Resource` compartido con el `TracerProvider` → cada log tendrá `service.name`.
- `BatchLogRecordProcessor` siempre en prod; `SimpleLogRecordProcessor` solo para debug.
- `provider.shutdown()` en el `finally` del `main`; sin esto, logs recientes se pierden al salir.
- Si tu stack ya corre `logging.basicConfig(...)`, llámalo **antes** o adjunta el handler explícitamente después para no perderlo.

> ¿Qué línea pierde logs si falta?

---

## 6. Structured logging (JSON) como mejor compañero

Un `logger.info("payment ok")` desnudo da un `body` string sin granularidad. En cambio:

```python
log = logging.getLogger(__name__)
log.info("payment ok", extra={"user_id": 123, "amount": 42.5, "currency": "USD"})
```

El handler OTel toma `extra` y lo mete en `attributes` del `LogRecord`. En Loki, esos atributos quedan accesibles por LogQL. Si además formateas el `body` como JSON (añadiendo un `logging.Formatter` que emite JSON), tienes consulta por campo sin regex frágil.

**Anti-patrón**: `logger.info(f"user {u} paid {a} {c}")` — pierdes queryability. **Patrón**: pasar los datos por `extra`.

> ¿Qué campo del LogRecord recibe los pares pasados por `extra`?

---

## 7. Severity mapping

| stdlib Python | nivel | OTel severity_number | OTel severity_text |
|---|---|---|---|
| `DEBUG` | 10 | 5 | DEBUG |
| `INFO` | 20 | 9 | INFO |
| `WARNING` | 30 | 13 | WARN |
| `ERROR` | 40 | 17 | ERROR |
| `CRITICAL` | 50 | 21 | FATAL |

El handler se encarga del mapping. Si usas niveles custom, pueden caer en el bucket más cercano o fallar — mejor evitarlo.

> ¿A qué `severity_number` mapea `WARNING`?

---

## 8. Export a Loki vía Collector

El patrón canónico es **nunca** exportar OTLP directo a Loki desde la app: siempre pasa por un Collector. El Collector tiene un `exporter: loki` (en contrib) que traduce el formato OTLP al API de Loki.

```yaml
# collector-config.yaml (fragmento)
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  batch:
    timeout: 1s

exporters:
  loki:
    endpoint: http://loki:3100/loki/api/v1/push

service:
  pipelines:
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [loki]
```

Loki indexa por **labels** (pocas, de baja cardinalidad: `service_name`, `env`, `level`). El resto del `LogRecord` (body + attributes) queda **buscable** vía LogQL `| json | user_id="123"`.

> ¿Por qué no exportar OTLP directo a Loki desde la app?

---

## 9. Dual-sink (stdout + OTLP)

Siempre mantén un handler `StreamHandler` adicional:

```python
root = logging.getLogger()
root.addHandler(logging.StreamHandler())           # stdout — para kubectl logs / docker logs
root.addHandler(LoggingHandler(logger_provider=provider))  # OTLP — para Loki
```

Motivos:
- Ante caída del Collector, no te quedas sin logs locales.
- `kubectl logs <pod>` sigue funcionando como siempre.
- Debugging local no requiere subir el stack entero.

Riesgo: duplicados en Loki si *también* tienes Promtail/filelog-receiver leyendo stdout → desactiva uno.

> ¿Qué pasa si Promtail está leyendo el stdout del pod **y además** tu app emite OTLP a Loki?

---

## 10. Shutdown ordenado y pérdidas silenciosas

`BatchLogRecordProcessor` acumula records y los envía cada `schedule_delay_millis` (default 1000 ms) o cuando llega al `max_export_batch_size` (default 512). Si la app sale antes del próximo flush, esos records se **pierden silenciosamente**.

Soluciones:

- `provider.shutdown()` en `finally` del main / en handlers de `SIGTERM`.
- Para scripts cortos (seed, migración), bajar `schedule_delay_millis` a 100 ms o usar `SimpleLogRecordProcessor` conscientemente.

> ¿Qué método hay que llamar en el shutdown para no perder los últimos records?

---

## 11. Madurez, warts, anti-patterns

Estado del signal:

- **Spec**: Log Data Model estable.
- **Python SDK**: GA; nombres de módulos con `_logs` (underscore inicial) por razones históricas — es público pero el guión bajo recuerda que algunos detalles pueden cambiar.
- **Collector Loki exporter**: estable en contrib; versiones recientes.
- **Grafana `TraceToLogs`**: requiere config en el datasource de Tempo apuntando al datasource de Loki + mapping de `trace_id`.

Anti-patterns reales:

- **Logs duplicados**: Promtail scrapea stdout **y** OTel bridge emite OTLP → cada log 2×. Elegir uno.
- **Dropped silently**: sin `shutdown()`, en apps CLI que terminan rápido, los últimos N logs no llegan.
- **Cardinalidad explosiva en labels**: promover `user_id` a label en Loki destruye el índice. Dejarlo en `attributes` del body.
- **`basicConfig` después del handler**: resetea los handlers del root. Orden importa.
- **Mismo exporter OTLP a dos backends**: no, poner dos processors/exporters diferentes.

> ¿Cuál de estos anti-patterns es el más común en apps que ya tenían Promtail?

---

## 12. Diagnóstico — "mi log no tiene traceId"

Lista de hipótesis en orden de probabilidad:

1. **El log se emitió fuera del span.** Verifica envolviéndolo en `with tracer.start_as_current_span("op"):`.
2. **El handler OTel no está adjunto al logger que llamas.** Chequea `logging.getLogger().handlers`.
3. **`logging.basicConfig(...)` corrió después** y reseteó handlers. Mueve la llamada.
4. **El span viaja en otro thread** (ejecutor sin context propagation). Usa `concurrent.futures` wrappeado o `copy_context()`.
5. **El SDK de traces no está inicializado** (no hay `TracerProvider`). Sin tracer, no hay span, no hay traceId.
6. **`sampling` descartó el trace** (`parent-based + ratio` bajo). El span existe pero `trace_flags` dice que no se exporta; el `trace_id` sí viajará igual al log, pero no verás el trace en Tempo.

Procedimiento práctico: emitir un log de prueba `logger.info("probe", extra={"probe": True})` justo antes y justo después del `start_as_current_span`. Si el primero no tiene `trace_id` y el segundo sí, el wiring está bien y el bug está en que el call site original está fuera del span.

> Si el log tiene `trace_id` pero no lo ves en Tempo, ¿qué hipótesis queda viva?
