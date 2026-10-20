# Ejemplo 01 — OTel Logging Handler mínimo

Demuestra el **wiring más corto posible** del handler bridge sin red: exporter `ConsoleLogExporter` que imprime cada `LogRecord` OTLP en stdout. Sirve para ver, con los ojos, cómo un `logger.info(...)` del stdlib se transforma en un record OTel completo.

## Qué vas a observar

- Un `LogRecord` OTLP con `severity_number`, `severity_text`, `body`, `attributes`, `resource` y `instrumentation_scope`.
- **Ausencia** de `trace_id`/`span_id` (no hay traces aquí — eso es el ejemplo 02).

## Correr

```bash
cd examples/01-python-logging-handler-otel
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python3 app.py
```

Si no tienes `python3`, instala Python 3.10+ y repite.

## Qué esperar

Para cada `logger.info(...)` verás por stdout algo parecido a:

```json
{
  "body": "servicio arrancado",
  "severity_number": "SeverityNumber.INFO",
  "severity_text": "INFO",
  "attributes": {"component": "boot"},
  "resource": {"service.name": "example-01", ...}
}
```

## Limpieza

```bash
deactivate 2>/dev/null || true
rm -rf .venv
```
