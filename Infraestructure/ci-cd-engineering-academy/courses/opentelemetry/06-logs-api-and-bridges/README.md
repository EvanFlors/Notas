# otel-06 — Logs API y bridges con `logging`

## Identificación

- **ID:** `otel-06-logs-api-and-bridges`
- **Curso:** `opentelemetry`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `otel-04-instrumenting-python-traces`. Python 3.10+, `pip`, `docker` (opcional para el ejemplo 03 y la actividad 02).

## Objetivo

Emitir **logs vía OpenTelemetry** sin romper la logging stack existente de la app. En Python, el camino recomendado es **no reemplazar `logging`** del stdlib, sino **adjuntar el OTel Logging Handler** que convierte cada `LogRecord` del stdlib en un **LogRecord OTLP** con **traceId/spanId** auto-correlacionado cuando hay un span activo. Al terminar, deberías ser capaz de añadir unos ~10 LOC a cualquier app Python ya instrumentada con traces y verla emitir logs correlacionados hacia Loki (o cualquier backend OTLP) con click-through desde un trace.

## Alcance

Este módulo cubre:

- El **data model** del `LogRecord` OTel (campos `timestamp`, `severity_number`, `severity_text`, `body`, `attributes`, `resource`, `trace_id`, `span_id`, `trace_flags`).
- La diferencia entre **Logs API** (producir records directamente) y **Bridges** (reutilizar `logging` del lenguaje) — y por qué los bridges son el patrón recomendado para apps existentes.
- El wiring del **OTel Logging Handler** de Python: `LoggerProvider` + `BatchLogRecordProcessor` + `OTLPLogExporter` + `LoggingHandler`.
- **Correlación automática traceId/spanId** cuando el record se emite dentro de un span activo.
- **Structured logging** (JSON) como mejor compañero del handler (atributos quedan como keys en el `body`/`attributes` y son queryable).
- Export a **Loki** vía Collector (`loki` exporter en contrib) y por qué el patrón es siempre `app → Collector → backend`.
- Estado de **madurez**: logs es el signal más joven de OTel; la API/SDK en Python es GA pero algunos backends y herramientas tienen rough edges.

Lo que **no** cubre (ya en otros módulos):

- Diseño del Collector multi-pipeline → `otel-08`.
- Patrones de despliegue agent vs gateway → `otel-09`.
- Scrubbing PII sobre logs vía OTTL → `otel-13`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-python-logging-handler-otel/` — handler mínimo, export a stdout (debug). Demuestra el wiring sin dependencias de red.
  - `02-structured-logs-with-trace-id/` — JSON logs + traceId/spanId correlacionado dentro de un span manual.
  - `03-logs-to-loki-via-collector/` — stack `docker compose` con Loki + Grafana + Collector; app Python exporta logs OTLP → Loki.
- **`activities/`**:
  - `01-add-otel-logging-to-capstone/` (guided-lab) — adjuntar el handler a una app existente y verificar correlación traceId en stdout.
  - `02-click-through-trace-to-logs/` (independent) — stack completo (Tempo + Loki + Grafana), capturar un trace multi-span con logs, demostrar click-through en Grafana.
- **`resources/links.md`** — docs oficiales, especificación de LogRecord, exporter Loki.

## Temas y subtemas

1. **El data model `LogRecord` de OTel**
   - Campos: `timestamp`, `observed_timestamp`, `severity_number` (1–24), `severity_text`, `body`, `attributes`, `resource`, `instrumentation_scope`, `trace_id`, `span_id`, `trace_flags`.
   - Diferencia con el `LogRecord` del `logging` del stdlib (nombres distintos; conversión 1:1 vía el handler).
2. **Logs API vs Bridges**
   - **Logs API**: `logger_provider.get_logger(...).emit(LogRecord(...))` — raro de usar directo en apps; sí lo usan librerías.
   - **Bridges**: adaptar un logging framework existente (`logging` en Python, `log/slog` en Go, Serilog en .NET, Logback en Java) para que cada record se convierta en un `LogRecord` OTLP.
3. **Wiring del OTel Logging Handler en Python**
   - `LoggerProvider` (análogo a `TracerProvider`), `Resource` compartido con traces/metrics (`service.name`, `service.version`).
   - `BatchLogRecordProcessor` + `OTLPLogExporter` (`grpc` o `http/protobuf`).
   - `LoggingHandler(level=INFO, logger_provider=...)` y `logging.getLogger().addHandler(handler)`.
4. **Correlación automática trace↔log**
   - Si hay un span activo en el `Context`, el handler lee `trace_id`, `span_id`, `trace_flags` y los adjunta al `LogRecord`.
   - En Grafana: traceId en el log → click-through al trace en Tempo (y viceversa, por `TraceToLogs`).
5. **Structured logging (JSON) con el handler**
   - `logger.info("payment ok", extra={"amount": 42, "currency": "USD"})` — `extra` acaba como attributes del `LogRecord` OTLP.
   - JSON formatter para stdout *además* del handler OTel (dual sink, no competir).
6. **Severity mapping**
   - stdlib `DEBUG=10 → OTel TRACE..DEBUG`; `INFO=20 → INFO`; `WARNING=30 → WARN`; `ERROR=40 → ERROR`; `CRITICAL=50 → FATAL`.
7. **Export a Loki vía Collector**
   - `receivers.otlp` → `processors.batch` → `exporters.loki` (en Collector contrib).
   - Loki indexa por labels (poca cardinalidad). Los `attributes` del log que terminen como labels deben ser pocos y de baja cardinalidad; el resto queda en el `body` searchable con LogQL.
8. **Dual-sink**
   - Mantener stdout/stderr (observable para `kubectl logs`, `docker logs`) **y** emitir OTLP: dos handlers en el mismo logger root.
9. **Qué romper evitar**
   - No duplicar logs (dos handlers no deben ser el mismo).
   - No bloquear la app por el exporter: usar `BatchLogRecordProcessor` nunca `SimpleLogRecordProcessor` en prod.
   - Shutdown ordenado: `logger_provider.shutdown()` para flushear el batch.
10. **Madurez del signal**
    - Logs API/SDK Python: **GA** (desde 2023).
    - Backends: Loki, Datadog, Honeycomb, Grafana Cloud aceptan OTLP logs; validar status.
    - `instrumentation` auto para logging (`opentelemetry-instrumentation-logging`) existe pero inyecta solo `trace_id`/`span_id` en el **formato** del `logging`; no reemplaza al handler OTel bridge.
11. **Patrón vs anti-patrón**
    - ✅ `logging` → handler OTel → OTLP → Collector → Loki.
    - ❌ Reescribir toda la app para usar la Logs API directa.
    - ❌ Shippear logs crudos de stdout a Loki (Promtail) **y** OTLP a la vez → duplicados.
12. **Evaluación mental**
    - "Si un log no tiene `trace_id` pero el request pasó por un span, ¿por qué?" — handler mal cableado, log emitido fuera del span, o `logging.basicConfig()` reemplazó el handler.

## Conceptos internos (fundamentos)

- **Por qué bridges y no reemplazo**: una app típica tiene cientos de call sites `logger.info(...)`. Reescribirlos a `otel_logger.emit(LogRecord(...))` es inviable y además las librerías de terceros emiten vía `logging`. El bridge recoge **todo** y lo convierte en origen.
- **De dónde sale el `trace_id` en el record**: el `LoggingHandler` consulta `opentelemetry.trace.get_current_span().get_span_context()` dentro de `emit()`. Si hay span activo (via ContextVars en Python async-safe), copia `trace_id`, `span_id`, `trace_flags`. Si no hay span, el record se emite sin esos campos y aparece "huérfano" en Loki.
- **Por qué JSON**: Loki prefiere labels de baja cardinalidad; todo lo demás es `body` + `attributes`. Un `body` JSON permite `| json` en LogQL y queries por campo. Dejar el `body` como texto plano desperdicia el potencial.
- **Qué pasa si llamas `logging.basicConfig()` después**: puede resetear los handlers del root y perder el handler OTel. Configurar OTel **después** de `basicConfig` o explícitamente añadir al root logger ya configurado.
- **`SimpleLogRecordProcessor` vs `BatchLogRecordProcessor`**: Simple exporta synchronously (útil solo para debugging; bloquea el hilo). Batch acumula y exporta en background con un worker thread; estándar en prod.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué el patrón bridge domina sobre la Logs API directa, y de dónde sale el `trace_id` en cada record. |
| Operativa | Adjuntar el OTel Logging Handler a una app Python existente en < 15 LOC, exportar a Collector y verificar correlación en Grafana. |
| Arquitectónica | Diseñar el flujo "dual sink" (stdout + OTLP) y decidir qué attributes del log se promueven a labels en Loki (poca cardinalidad). |

## Entregables

- App Python del capstone con logs correlacionados por `traceId` visibles en Loki.
- Demo de click-through trace→logs en Grafana (via Tempo `TraceToLogs`).
- Las dos `tests/validate.sh` de las actividades pasan (o reportan `SKIP` si falta `python3`/`docker`).

## Criterios de evaluación

- Explicar en 3 frases por qué el bridge pattern vence al Logs API directo en apps brownfield.
- Diagnosticar un log sin `trace_id` cuando debería tenerlo (handler no cableado, `basicConfig` posterior, log fuera del span, o span mal propagado).
- Diseñar el mapping "attribute → label de Loki" para una app dada evitando explosión de cardinalidad.

## Secuencia recomendada

1. Lee `theory/lesson.md` secciones 1–6.
2. Reproduce `examples/01-python-logging-handler-otel/` (todo offline, stdout).
3. Reproduce `examples/02-structured-logs-with-trace-id/` (correlación dentro de un span manual).
4. Si tienes Docker, reproduce `examples/03-logs-to-loki-via-collector/`.
5. Haz `activities/01-add-otel-logging-to-capstone/`.
6. Haz `activities/02-click-through-trace-to-logs/`.

## Siguiente

→ `otel-07-context-propagation-across-services`: ahora que trace, metric y log viajan juntos *dentro* de un servicio, hay que mantenerlos *vivos* a través de varios servicios y lenguajes.
