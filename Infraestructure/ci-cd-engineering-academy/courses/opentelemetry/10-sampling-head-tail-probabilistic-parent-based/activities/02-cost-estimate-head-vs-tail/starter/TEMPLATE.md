# Análisis de costo — head vs tail sampling

> **Copia este archivo a `analysis.md` y rellénalo.** No borres los encabezados; el
> validador los busca. La palabra `RELLENAR` marca dónde escribir.

## Supuestos

- 1000 req/s, 10 spans/trace, 1.5 KB/span.
- Tasa de error: 1%. Slow (>500ms): 5%. Overlap error∩slow: despreciable.
- Backend: $0.10/GB ingested, $0.03/GB-mes storage, retención 7 días.
- `decision_wait = 10s`.

## Cálculos

### Estrategia A — Head uniforme (ratio 10%)

- Fracción retenida: RELLENAR
- Spans/s: RELLENAR
- GB/día: RELLENAR
- $/día (ingest + storage): RELLENAR

### Estrategia B — Error-first + 10% probabilistic (sin cap)

- Fracción retenida: RELLENAR
- Spans/s: RELLENAR
- GB/día: RELLENAR
- Memoria Collector (MB): RELLENAR
- $/día: RELLENAR

### Estrategia C — Error-first + probabilistic + rate_limiting 1500 spans/s

- Fracción retenida (antes de cap): RELLENAR
- Spans/s **capped**: RELLENAR
- GB/día: RELLENAR
- Memoria Collector (MB): RELLENAR
- $/día: RELLENAR

## Tabla comparativa

| Estrategia | Spans/s | GB/día | $/día | Errores capturados | Blind spot |
|---|---|---|---|---|---|
| A | RELLENAR | RELLENAR | RELLENAR | RELLENAR | RELLENAR |
| B | RELLENAR | RELLENAR | RELLENAR | RELLENAR | RELLENAR |
| C | RELLENAR | RELLENAR | RELLENAR | RELLENAR | RELLENAR |

## Recomendación

RELLENAR en al menos 3 líneas. Debe mencionar: memoria del Collector, blind spot
(o "ciego al resultado"), restricción topológica (loadbalancing exporter) si
usas tail-based, compromiso de latencia de visualización (`decision_wait`).

## Trade-offs sacrificados por B/C vs A

RELLENAR al menos uno: p. ej. memoria, complejidad, latencia de visualización,
requisito de topología.
