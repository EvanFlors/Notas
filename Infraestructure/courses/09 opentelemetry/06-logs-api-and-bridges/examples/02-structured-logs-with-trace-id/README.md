# Ejemplo 02 — Structured logs con trace_id auto-correlacionado

Añade al ejemplo 01 un **TracerProvider** mínimo y un `with tracer.start_as_current_span(...)`. El log emitido dentro del span lleva `trace_id` y `span_id`; el log emitido fuera, no. Pedagogía 100%.

## Correr

```bash
cd examples/02-structured-logs-with-trace-id
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python3 app.py
```

## Qué esperar

- El primer log (fuera del span) aparece con `trace_id="0x00000...0"`.
- Los logs dentro del `with` aparecen con un `trace_id` real (32 chars hex) y `span_id` (16 chars hex) consistentes entre sí.
- El log después del `with` vuelve a estar sin `trace_id`.

Observa cómo los campos pasados por `extra={...}` acaban en `attributes` del `LogRecord`.

## Limpieza

```bash
deactivate 2>/dev/null || true
rm -rf .venv
```
