# Ejemplo 03 — Consistent sampling: dos servicios, dos escenarios

Simula dos servicios encadenados (A → B) y compara dos configuraciones:

- **Consistente**: ambos usan `ParentBased(TraceIdRatioBased(0.1))`. A decide, B honra.
- **Divergente** (anti-pattern): A y B deciden independientemente al 10%, *sin* `ParentBased`. Resultado: traces incompletos sistemáticos.

El ejemplo es puramente Python (sin Docker), por lo que corre siempre.

## Requisitos

- Python 3.10+ con `opentelemetry-api/sdk` (ver `requirements.txt`).

## Correr

```bash
cd examples/03-consistent-sampling/
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python3 app.py
```

Salida esperada:

```
== CONSISTENT (ParentBased in both) ==
A sampled: ~100, B honored: 100% of A-sampled (same decision)
Orphan traces (A sampled, B dropped): 0

== DIVERGENT (independent ratio in both) ==
A sampled: ~100, B sampled: ~100
Both sampled: ~10 (expected ~10%*10% = ~1%)
Orphan traces: large (~180)
```

## Qué observar

- `TraceIdRatioBased(0.1)` es **determinístico** sobre el mismo `trace_id`. Con **el mismo ratio** en ambos servicios, la decisión coincide incluso sin propagación — pero sólo si todos usan el mismo ratio. En cuanto difieren los ratios, aparecen huérfanos.
- `ParentBased` resuelve el problema en general: el servicio downstream **no re-decide**, honra lo que vino en el `traceparent`. Es la única forma segura cuando no puedes garantizar ratios idénticos.
- La propagación entre A y B se simula creando manualmente el `SpanContext` con el `trace_id` + `trace_flags` que A decidió.

## Limpieza

`deactivate && rm -rf .venv`. No hay servicios externos.
