# otel-10-02 — Estimación de costo: head vs tail sampling

## 1. Identificación
- **ID:** `otel-10-02-cost-estimate-head-vs-tail`
- **Tecnología:** opentelemetry
- **Módulo:** 10-sampling-head-tail-probabilistic-parent-based
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

Antes de recomendar un cambio de política de sampling al equipo de plataforma, debes **estimar el costo** de cada opción. El dashboard de monitoreo reporta hoy:

- **Tráfico**: 1000 req/s sostenido (86.4M req/día).
- **Spans por request**: 10 promedio.
- **Tamaño de span**: 1.5 KB serializado OTLP (con atributos semconv).
- **Tasa de error**: 1% (si no sabes, usa 1%).
- **p95 latencia**: 400 ms; **p99**: 1200 ms. Treshold "slow" = 500 ms → ~5% de requests son slow.
- **Backend**: cobra $0.10/GB **ingested** y $0.03/GB-mes de **storage** (retención 7 días).

Se evalúan tres estrategias:

| # | Nombre | Head (SDK) | Tail (gateway) |
|---|---|---|---|
| A | Baseline uniforme | `TraceIdRatioBased(0.10)` | — |
| B | Error-first | `AlwaysOn` | 100% ERROR + 100% latency>500ms + 10% probabilistic |
| C | Error-first con budget | `AlwaysOn` | 100% ERROR + 100% latency>500ms + 10% probabilistic + rate_limiting 1500 spans/s |

## 3. Objetivos

- Calcular, para cada estrategia, **spans/s retenidos**, **GB/día ingested** y **$/día** (ingest + storage).
- Dimensionar la **memoria del Collector** necesaria en B y C.
- Recomendar una estrategia justificada en texto, no sólo numéricos.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` secciones 5, 6, 8 y 9.
- Un editor de texto (markdown) o papel. Opcional: `python3`.
- Costo: 0.

## 5. Instrucciones

**No reveles la solución.** Trabaja los números tú mismo.

1. Para cada estrategia, calcula:
   - `spans_retenidos_s` = fracción de traces retenidos × 10 spans/trace × 1000 req/s.
     - En A: fracción = 0.10 (uniforme).
     - En B: fracción = `errores(1%) + slow_no_errored(~5%) + probabilistic(10% del resto que no sea error ni slow)`. Cuidado: los conjuntos **se solapan parcialmente**; aproxima asumiendo independencia (ERROR y slow son casi ortogonales en frecuencia).
     - En C: igual que B pero **capped** a 1500 spans/s si lo excede.
   - `GB_dia_ingested` = `spans_retenidos_s × 1.5 KB × 86 400 s / 10^9`.
   - `$_dia_ingest` = `GB_dia_ingested × 0.10`.
   - `$_mes_storage` = `GB_dia_ingested × 7 × 0.03`.
   - `$_dia_total` ≈ `$_dia_ingest + $_mes_storage / 30`.
2. Para B y C, estima la **memoria del Collector**:
   - `mem_MB ≈ (req/s × decision_wait_s) × spans/trace × 1.5 KB × overhead(1.5)`.
   - Usa `decision_wait=10s`.
3. Copia `starter/TEMPLATE.md` a `starter/analysis.md` y rellénalo. Debe incluir:
   - Tabla comparativa de las tres estrategias.
   - **Recomendación** (A, B o C) con justificación de **al menos tres líneas**: menciona observabilidad de errores, costo y riesgo operativo.
   - **Un trade-off que B/C sacrifica** vs A (hint: hay más de uno).
4. (Opcional) Usa `starter/compute.py` como calculadora: `python3 starter/compute.py`.

## 6. Resultado esperado

- `starter/analysis.md` relleno con los números calculados y una recomendación justificada.
- Mencionas explícitamente **memoria del Collector** y **blind spot** o **latencia de visualización**.
- Mencionas la **restricción topológica** del tail-sampling (todos los spans del mismo trace al mismo Collector).

## 7. Criterios de aceptación

- Las sumas de GB/día en A y B difieren en el orden correcto (B > A siempre; el ahorro de head viene del uniform).
- La recomendación cita **al menos dos** criterios (no sólo "más barato").
- `tests/validate.sh` encuentra las secciones esperadas con exit 0.

## 8. Validación

```bash
bash tests/validate.sh starter/analysis.md
```

El script verifica que:

- El archivo existe y no es la plantilla sin tocar.
- Contiene las palabras clave `memoria`, `decision_wait`, `blind spot` o `ciego`, y `recomend` (español).
- Hay una tabla markdown con al menos las tres estrategias (líneas que empiezan por `|` con "A", "B" y "C").

## 9. Preguntas de reflexión

1. Si el tráfico sube a 10 000 req/s, ¿sigue siendo rentable tail-based?
2. ¿Qué pasa con los **traces largos** (async, batch) bajo `decision_wait=10s`?
3. ¿Cómo cambia la ecuación si el backend cobra por **traces únicos** en vez de por GB?
4. ¿Qué métrica del propio Collector monitorearías para detectar saturación de buffer?

## 10. Extensiones

- Añade una estrategia D: head al 50% + tail 100% errores + 5% probabilistic. ¿Qué cambia?
- Grafica las tres estrategias (gnuplot/matplotlib) en un diagrama Pareto costo vs recall de errores.
- Negocia con "finance": límite duro de $100/día; ¿qué configuración lo cumple sin perder errores?

## 11. Limpieza

No deja artefactos. Si usaste `compute.py` sólo imprime a stdout.
