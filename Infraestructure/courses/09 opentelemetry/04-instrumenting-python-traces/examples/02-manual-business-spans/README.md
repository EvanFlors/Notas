# Ejemplo 02 — Manual business spans (nested, attributes, events)

Un script Python standalone (sin servidor HTTP) que ilustra:

- Configuración programática del `TracerProvider` + `BatchSpanProcessor` + `ConsoleSpanExporter`.
- Spans anidados mediante `start_as_current_span` → padre/hijo automático via Context.
- `set_attribute` con namespaces de dominio (`checkout.*`, `payment.*`).
- `add_event` para marcar hitos (`fraud.check.passed`).
- `shutdown()` para flush del batch antes de salir.

## Requisitos

```bash
pip install opentelemetry-api opentelemetry-sdk
```

## Correr

```bash
cd $(dirname "$0")
bash run.sh
```

El script ejecuta `app.py`, que simula un checkout: `checkout.process` → `inventory.reserve` + `payment.charge`. Verifica que los 3 span names aparecen y que la jerarquía parent/child es correcta (mismo trace_id, parent_id del hijo = span_id del padre).

## Qué observar

- Un único `trace_id` compartido por los 3 spans.
- `parent_id` de `inventory.reserve` y `payment.charge` = `span_id` de `checkout.process`.
- Atributos de dominio presentes en el output JSON.
- Un evento `fraud.check.passed` embebido en el span padre.
