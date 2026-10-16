# Ejemplo 03 — `record_exception` y `set_status`

Ilustra el flujo correcto cuando un span falla:

1. `record_exception(exc)` → añade un evento `exception` con atributos semconv (`exception.type`, `exception.message`, `exception.stacktrace`).
2. `set_status(StatusCode.ERROR, ...)` → marca el span rojo en el backend.
3. `raise` para que la excepción no se trague (opcional).

También muestra el atajo:

```python
with tracer.start_as_current_span("op", record_exception=True, set_status_on_exception=True) as span:
    ...
```

## Requisitos

```bash
pip install opentelemetry-api opentelemetry-sdk
```

## Correr

```bash
cd $(dirname "$0")
bash run.sh
```

## Qué observar

- Dos spans: `payment.charge.manual-handling` y `payment.charge.auto-handling`.
- Ambos con status `ERROR` y evento `exception` adjunto.
- `exception.type = ValueError`, `exception.message = "card declined"`.
