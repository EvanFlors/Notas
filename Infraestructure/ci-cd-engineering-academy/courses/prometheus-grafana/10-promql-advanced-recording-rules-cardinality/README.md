# obs-10 — PromQL avanzado, recording rules y control de cardinalidad

## Identificación

- **ID:** `obs-10-promql-advanced-recording-rules-cardinality`
- **Curso:** `prometheus-grafana`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `obs-04` (PromQL fundamentos), `obs-07` (instrumentación con Python).

## Objetivo

**Optimizar queries, pre-calcular con recording rules y controlar la cardinalidad.** Al terminar, el estudiante escribe joins binarios no triviales, define recording rules reutilizables como "ingredientes" para dashboards y alertas, y diagnostica/elimina explosiones de cardinalidad en una TSDB real.

## Alcance

Este módulo cubre:

- **Patrones avanzados de PromQL**: joins binarios (`on`, `ignoring`, `group_left`, `group_right`), series matching, subqueries.
- **Recording rules**: convención de namespace con `:` (`job:http_requests:rate5m`), diseño como "ingredientes" compuestos, costos de evaluación.
- **Troubleshooting de cardinalidad**: endpoint `/api/v1/status/tsdb`, métricas `prometheus_tsdb_head_series` / `prometheus_tsdb_head_chunks`, top-N series por métrica con `topk(10, count by (__name__)({__name__!=""}))`.
- **Fuentes frecuentes de cardinalidad**: IDs únicos, timestamps en labels, user agents, paths de alta variabilidad, labels del sistema SD.
- **Native histograms** vs classic histograms: trade-offs, migración gradual, estado de soporte.

Lo que **no** cubre:

- Escala horizontal y long-term storage → `obs-11`.
- Prometheus Operator → `obs-12`.
- SLOs y burn-rate alerts (que *consumen* las recording rules diseñadas aquí) → `obs-14`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-recording-rule-for-slo-ingredient/` — definir y evaluar una recording rule que calcula `job:http_requests:rate5m` reutilizable por dashboards y alertas.
  - `02-cardinality-top-offenders/` — queries diagnósticas sobre `__name__` para encontrar los top ofensores.
  - `03-native-histogram-compare/` — comparar classic histogram (buckets) vs native histogram para una misma métrica de latencia.
- **`activities/`**:
  - `01-define-recording-rules-for-capstone/` — guided-lab: diseñar 3 recording rules del capstone (RED metrics) y verificar con `promtool`.
  - `02-forensic-cardinality-explosion/` — independent: Prometheus crasheó por OOM; el estudiante localiza al ofensor (una métrica con `user_id`) y aplica `metric_relabel_configs: action: drop`.
- **`resources/links.md`**.

## Conceptos internos (fundamentos)

- Cada combinación única de labels es **una serie**; cada serie cuesta RAM (índice + chunks activos) proporcionalmente.
- Las recording rules convierten queries O(N series × range) en O(1) a cambio de más storage (nuevas series pre-calculadas).
- `rate()` + `sum by (...)` sobre series con alta cardinalidad gasta CPU **cada vez que se evalúa**; una recording rule paga ese costo una vez por intervalo de scrape.
- Un `__name__` nuevo con una label de alta cardinalidad puede multiplicar la TSDB por 10× en minutos; sin alertas sobre `prometheus_tsdb_head_series` el crash llega por OOM.
- `metric_relabel_configs` con `action: drop` es la red de seguridad post-scrape; la fix definitiva es sacar la label en el productor.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué un `group_left` es necesario cuando se multiplican dos series con cardinalidades distintas; distinguir recording rule vs query ad-hoc; justificar cuándo migrar a native histograms. |
| Operativa | Escribir recording rules siguiendo la convención `level:metric:operation`; usar `topk(10, count by (__name__)({__name__!=""}))` para localizar ofensores; configurar `metric_relabel_configs` para dropear una label o una métrica entera. |
| Arquitectónica | Diseñar la "capa de ingredientes" (recording rules reutilizables) sobre la que se montan dashboards y alertas; decidir qué métricas aceptan qué nivel de cardinalidad; proponer límites y alertas de meta-observabilidad. |

## Entregables

- `PrometheusRule` con 3 recording rules del capstone validadas con `promtool test rules`.
- Reporte de cardinalidad del Prometheus local: top-10 métricas, top-10 labels, hipótesis del origen.
- Fix de cardinalidad: diff del `prometheus.yml` con `metric_relabel_configs` o del código de la app Python eliminando la label culpable.

## Criterios de evaluación

- `promtool check rules` pasa sobre las recording rules escritas.
- La query `topk(5, count by (__name__)({__name__!=""}))` corre y el estudiante interpreta la salida.
- Dada la actividad 02, el estudiante nombra correctamente la métrica ofensora y aplica el `drop` que estabiliza la TSDB.
- El estudiante justifica por escrito por qué una recording rule reduce costo de alertas que corren cada 30 s.

## Secuencia recomendada

1. Leer `theory/lesson.md` (una pasada).
2. Reproducir `examples/01-recording-rule-for-slo-ingredient/` y verificar la evaluación con `promtool`.
3. Reproducir `examples/02-cardinality-top-offenders/` sobre el Prometheus local del curso.
4. Reproducir `examples/03-native-histogram-compare/`.
5. Hacer `activities/01-define-recording-rules-for-capstone/` (guiada).
6. Hacer `activities/02-forensic-cardinality-explosion/` (independiente).
7. Responder las preguntas de reflexión de cada actividad.

## Siguiente

→ `obs-11-scale-and-long-term-storage`: cuando el single-node ya no alcanza, long-term store (Thanos / Mimir / VictoriaMetrics).
→ `obs-14-slo-and-burn-rate-alerts`: consume las recording rules diseñadas aquí como "ingredientes SLO".
