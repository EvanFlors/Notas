# Solución de referencia — cost estimate

> Esta es una solución de referencia, no la única válida. Un análisis equivalente
> con números dentro de ±15% y recomendación bien justificada también pasa.

## Supuestos

- 1000 req/s, 10 spans/trace, 1.5 KB/span.
- Tasa de error: 1%. Slow (>500ms): 5%. Overlap error∩slow: despreciable (<0.05%).
- Backend: $0.10/GB ingested, $0.03/GB-mes storage, retención 7 días.
- `decision_wait = 10s`.
- Base: 10 000 spans/s con `AlwaysOn`.

## Cálculos

### A — Head uniforme 10%

- Fracción retenida: 0.10
- Spans/s: 10 000 × 0.10 = **1 000**
- GB/día: 1 000 × 1.5 KB × 86 400 s = **129.6 GB/día**
- $/día: 129.6 × $0.10 (ingest) + (129.6 × 7 × $0.03) / 30 (storage) ≈ 12.96 + 0.91 = **$13.87/día**

### B — Error-first + 10% probabilistic (sin cap)

- Fracción retenida: 1% + 5% + 10% × (1 − 1% − 5%) = **0.154**
- Spans/s: 10 000 × 0.154 = **1 540**
- GB/día: 1 540 × 1.5 KB × 86 400 / 1e9 = **199.6 GB/día**
- Memoria Collector: 1 000 × 10 × 10 × 1 500 B × 1.5 ≈ **225 MB**
- $/día: 199.6 × $0.10 + (199.6 × 7 × $0.03) / 30 ≈ **$21.36/día**

### C — Error-first + probabilistic + rate_limiting 1500 spans/s

- Fracción retenida antes de cap: 0.154
- Spans/s capped: **1 500** (fracción efectiva 0.150)
- GB/día: 1 500 × 1.5 KB × 86 400 / 1e9 = **194.4 GB/día**
- Memoria Collector: **~225 MB** (igual que B; el rate limiter cae tras la decisión)
- $/día: ≈ **$20.80/día**

## Tabla comparativa

| Estrategia | Spans/s | GB/día | $/día | Errores capturados | Blind spot |
|---|---|---|---|---|---|
| A | 1 000 | 129.6 | 13.87 | ~10% de errores | **90% de errores perdidos** |
| B | 1 540 | 199.6 | 21.36 | 100% | Memoria +225 MB; latencia visualización +10s |
| C | 1 500 | 194.4 | 20.80 | 100% salvo en tormenta | Si la tasa de error explota, el cap empieza a descartar errores |

## Recomendación

**B** para la mayoría de los casos. Captura 100% de errores con un 54% más de costo
que A ($21.36/día vs $13.87/día), diferencia trivial comparada con el valor de
diagnóstico. La memoria del Collector (~225 MB con `decision_wait=10s`) es
holgada. Riesgo operativo: todos los spans de un trace deben llegar al mismo
Collector; obliga a usar `loadbalancing` exporter upstream y a aceptar
~10 s de latencia de visualización por el `decision_wait`.

**C** sólo si hay un presupuesto duro y aceptamos el blind spot de que, en una
tormenta de errores, el `rate_limiting` empieza a descartar — exactamente cuando
más necesitas visibilidad.

**A nunca** en producción con SLOs: pierde 90% de los incidentes.

## Trade-offs sacrificados por B/C vs A

- **Memoria** stateful del Collector (buffer por `trace_id`).
- **Latencia de visualización**: nada aparece antes de `decision_wait`.
- **Topología forzada**: `loadbalancing` exporter + afinidad por `trace_id`.
- **Complejidad operativa**: una política mal escrita puede sampling 100% y matar el ahorro.
