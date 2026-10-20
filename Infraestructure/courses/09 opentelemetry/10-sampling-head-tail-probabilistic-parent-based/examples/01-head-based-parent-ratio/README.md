# Ejemplo 01 — Head-based sampling con `ParentBased(TraceIdRatioBased(0.1))`

Muestra cómo el SDK Python decide **al inicio del root span** si una traza se muestrea, con un ratio determinístico de 10% sobre `trace_id`. Verás que:

1. Aproximadamente 1 de cada 10 traces se muestrea (en 1000 iteraciones).
2. La decisión es **determinística**: el mismo `trace_id` siempre produce la misma decisión.
3. Si un trace entrante trae `traceparent` con `sampled=1`, se honra (no se re-decide).

## Requisitos

- Python 3.10+
- `pip install opentelemetry-api opentelemetry-sdk` (ver `requirements.txt`).

## Correr

```bash
cd examples/01-head-based-parent-ratio/
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python3 app.py
```

Salida esperada: línea final `SAMPLED ~= 0.09–0.11 (ratio=0.10)` y aviso de que un `traceparent` con flag `01` se honra siempre.

## Qué observar

- `sampler = ParentBased(root=TraceIdRatioBased(0.1))`: el wrapper hace que, si *hay* padre (span local o `traceparent` entrante), se respete; sólo cuando el span es *root* se consulta el ratio.
- `TraceIdRatioBased(0.1)` compara los 64 bits superiores del `trace_id` con `0.1 * 2^64`. **Idéntica entrada → idéntica salida** en cualquier servicio con el mismo ratio: ésa es la base de la consistencia.

## Limpieza

`deactivate && rm -rf .venv`. No hay servicios externos.
