# Cost analysis — acme-starter observability bill

## Resumen de la factura

Mes de 30 días. Precios: gold $0.80/1k series/mes y $0.80/GB logs; silver $0.50; bronze $0.20; trazas $0.50/M spans; egress $0.02/GB.

Total mensual estimado: **$1 940.47**.

Desglose por categoría:

| Categoría | $/mes    | % total |
|-----------|---------:|--------:|
| Métricas  | $101.20  |  5.2 %  |
| Logs      | $1 702.80| 87.8 %  |
| Trazas    | $123.47  |  6.4 %  |
| Egress    | $13.00   |  0.7 %  |
| **Total** | **$1 940.47** | 100 % |

Observación inmediata: logs dominan la factura (~88 %). Métricas y trazas son modestas en comparación. Esto es típico cuando la retención de logs es generosa y hay servicios en `debug` level en prod.

## Top-3 contribuyentes

1. **billing-worker** (payments/gold) — **$613.68** (metrics $7.20, logs $600.00, traces $6.48). Un solo servicio consume el 31 % de la factura total.
2. **checkout** (payments/gold) — **$504.48** (metrics $33.60, logs $432.00, traces $38.88). 26 % del total.
3. **orders** (commerce/gold) — **$280.93** (metrics $17.60, logs $240.00, traces $23.33). 14.5 % del total.

Los tres juntos: **$1 399.09 ≈ 72 % de la factura**.

## Causa raíz

Dos causas separadas:

- **billing-worker**: 25 GB/día de logs en un worker es brutal — señal clara de `debug`/`trace` nivel activado en producción, probablemente heredado de un incidente que nadie limpió. 25 GB × 30 × $0.80 = $600 solo de logs; sus series y spans son modestos.
- **checkout**: 42 000 series activas en un solo servicio es *mucho* para un endpoint RED estándar. El starter indica `OJO: incluye user_id como label`. Si asumimos 100 000 users activos, cada métrica se multiplica por ese factor → cardinality explosion. Las métricas crecen (de un baseline ~15 k a 42 k) y los logs también (18 GB/día, posiblemente también por tracing con user_id en message).
- **orders** sigue el patrón "tier gold legítimo con mucho tráfico": sus 22 k series y 10 GB logs son defendibles, no son un bug — simplemente es un servicio core caro.

Patrón adicional (secundario): `catalog` tiene sampling 10 % siendo silver, cuando el default silver debería ser 5 %. Pequeño, pero ilustrativo del drift.

## Optimización 1

**Ajustar nivel de log de billing-worker de `debug` a `info` y aplicar drop en el agente (Alloy/Vector) de líneas con patrón `db.query ... took=`.**

- Impacto esperado: reducir 25 GB/día → ~5 GB/día (-80 %).
- Ahorro: `20 GB/día × 30 × $0.80 = $480/mes`.
- Riesgo: perder visibilidad fine-grained para debugging. Mitigación: mantener nivel debug via feature flag activable 1 h por on-call cuando haga falta.

## Optimización 2

**Eliminar la label `user_id` de las métricas de checkout vía `metric_relabel_configs` (parche) + arreglar instrumentation para no emitirla (fix real).**

- Impacto esperado: 42 k series → ~15 k series (nivel baseline de un RED limpio).
- Ahorro métricas: `(42000 - 15000) / 1000 × $0.80 = $21.60/mes`.
- Impacto adicional en logs: si checkout también estructuraba logs por `user_id`, se puede esperar reducción adicional 15-25 % en logs del servicio. Siendo conservadores, 20 % de 18 GB/día = 3.6 GB/día × 30 × $0.80 = $86.40/mes.
- Ahorro total optimización 2: `$21.60 + $86.40 = $108/mes`.
- Riesgo: perder capacidad de "ver qué pasó con el usuario X". Mitigación: usar `exemplar` (vínculo métrica → trace en Tempo), que es gratis en series y permite drill-down al trace del usuario puntual.

## Ahorro total estimado

- Optimización 1: **$480/mes** (billing-worker logs).
- Optimización 2: **$108/mes** (checkout cardinality + logs).
- **Total ahorro: ~$588/mes = 30.3 % de la factura mensual.**

Factura proyectada post-optimizaciones: ~$1 352/mes. Volveríamos al rango razonable para 12 servicios con una base majority silver/bronze. El resto del gap (de $1 352 a $700-800 "ideal") se cierra con ajustes de retención de logs y revisando sampling de trazas en los servicios silver que están a 10 % cuando deberían estar a 5 %.
