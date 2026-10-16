# Solution notes

## Qué faltaba en el starter

1. **`errors-100`** policy (`status_code` con `status_codes: [ERROR]`) — garantiza 100% de errores.
2. **`random-10`** policy (`probabilistic` con `sampling_percentage: 10`) — baseline estadístico.
3. **`batch`** después de `tail_sampling` en el pipeline. El starter sólo tenía `[tail_sampling]`; el fix: `[tail_sampling, batch]`.

## Por qué `batch` va DESPUÉS de `tail_sampling`

- `tail_sampling` buffer-ea los spans por `decision_wait` segundos y los libera en ráfaga al decidir.
- Sin `batch` downstream, esas ráfagas golpean el exporter de una vez (file o OTLP) y pueden saturar red/IO.
- `batch` agrupa y suaviza en ventanas de `timeout: 1s`.
- Si invertimos: `batch` antes de `tail_sampling` sería inútil (los spans ya los tengo que buffer-ear para la decisión de todas formas; el batch no agrupa nada útil).

## Dimensionamiento

Para la carga del lab (300 traces en segundos): `num_traces: 10000` es muy generoso. En producción:

```
num_traces ≈ expected_traces_per_sec × decision_wait × factor_pico (1.5–2)
```

Para 1000 req/s y `decision_wait=10s`: `num_traces ≥ 20000`.
