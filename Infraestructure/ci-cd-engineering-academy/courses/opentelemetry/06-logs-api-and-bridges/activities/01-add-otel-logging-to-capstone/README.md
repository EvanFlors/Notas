# Actividad 01 — Adjuntar OTel Logging Handler a una app Python

## 1. Identificación

- **ID:** `otel-06-01-add-otel-logging-to-capstone`
- **Tecnología:** opentelemetry
- **Módulo:** `06-logs-api-and-bridges`
- **Dificultad:** intermediate
- **Duración estimada:** 40 min
- **Tipo:** guided-lab

## 2. Contexto

Tienes una app Python (`starter/app.py`) que ya emite traces por stdout vía `ConsoleSpanExporter`. **Falta** el bridge de logs. Tu trabajo: añadir el wiring OTel sobre `logging` del stdlib **sin modificar los call sites existentes** y verificar que cada `logger.info(...)` dentro de un span acaba con `trace_id` y `span_id` reales.

El validador no requiere Docker: usa `ConsoleLogRecordExporter` para que todo quede local.

## 3. Objetivos

- Configurar un `LoggerProvider` con `Resource` compartido con el `TracerProvider`.
- Adjuntar `LoggingHandler` al root logger sin perder los handlers existentes.
- Comprobar que los records emitidos dentro de un span tienen `trace_id` no-cero.
- Hacer `provider.shutdown()` ordenado al salir.

## 4. Prerrequisitos

- Python 3.10+.
- `pip`.
- Permisos de escritura en `/tmp/`.
- Costos: cero.

## 5. Instrucciones

### Paso 0 — Preparar

```bash
export WORK="/tmp/otel-06-01"
rm -rf "$WORK" && mkdir -p "$WORK"
cp -R starter/* "$WORK/"
cd "$WORK"
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

### Paso 1 — Mirar lo que ya hay

Lee `app.py`. Observa:

- Un `TracerProvider` con `ConsoleSpanExporter` ya montado.
- Función `handle_order(order_id)` que abre un span y hace algunos `logger.info(...)`.
- **No hay** `LoggerProvider` ni `LoggingHandler`.
- Al correr `python3 app.py`, los logs salen por stdout pero sin `trace_id`.

### Paso 2 — Añadir el wiring de logs

Modifica `app.py` para que **antes** de ejecutar `handle_order`:

1. Crea un `LoggerProvider` con **el mismo `Resource`** que el `TracerProvider`.
2. Añade un `BatchLogRecordProcessor(ConsoleLogRecordExporter())`.
3. Adjunta `LoggingHandler(level=logging.INFO, logger_provider=lp)` al root logger.
4. Expón el `LoggerProvider` como `_LOGGER_PROVIDER` (nombre a nivel de módulo) para que el `shutdown` lo llame.

### Paso 3 — Shutdown ordenado

En el `finally` del `main`, además del `tp.shutdown()`, llama `_LOGGER_PROVIDER.shutdown()`. Sin esto, los últimos records del batch se pierden.

### Paso 4 — Verificar

```bash
python3 app.py > out.json 2>&1
grep -c '"severity_number"' out.json      # debe ser >= 3 (al menos 3 logs OTel)
grep -c '"trace_id": "0x[0-9a-f]*[1-9a-f]' out.json   # debe ser >= 3 (al menos 3 con trace_id)
```

## 6. Resultado esperado

- `out.json` existe en `$WORK/`.
- Contiene al menos **3 LogRecord OTel** (ConsoleLogRecordExporter imprime JSON).
- De esos, al menos **3** tienen `trace_id` no-cero (todos los dentro del `with start_as_current_span`).
- El Resource de cada record contiene `service.name` = `otel-06-01-capstone`.

## 7. Criterios de aceptación

- No modificaste las llamadas `logger.info(...)` existentes.
- Reusas el mismo `Resource` para traces y logs.
- Llamas `shutdown()` en el `finally`.
- `tests/validate.sh` pasa.

## 8. Validación

```bash
bash tests/validate.sh
```

Si no tienes `python3`, el validador reporta `SKIP` con instrucciones.

## 9. Preguntas de reflexión

1. ¿Qué pasaría si llamaras `logging.basicConfig(level=logging.INFO)` **después** de `addHandler(LoggingHandler(...))`? Pruébalo y observa.
2. Si quisieras un record con `trace_id` sin estar dentro de ningún `start_as_current_span`, ¿cómo lo harías? ¿Es buena idea?
3. ¿Por qué se re-usa el mismo `Resource` entre `TracerProvider` y `LoggerProvider`?

## 10. Extensiones (opcionales)

- Añade un segundo handler `StreamHandler()` para mantener stdout "humano" además del JSON OTel.
- Reemplaza `ConsoleLogRecordExporter` por `OTLPLogExporter(endpoint="http://localhost:4317", insecure=True)` y levanta el stack del ejemplo 03.
- Mide: con `BatchLogRecordProcessor` default (schedule 1s), si no haces `shutdown`, ¿cuántos de los últimos logs se pierden?

## 11. Limpieza

```bash
deactivate 2>/dev/null || true
rm -rf /tmp/otel-06-01
```
