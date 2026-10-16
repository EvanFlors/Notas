# obs-11 — Scale and long-term storage

## Identificación

- **ID:** `obs-11-scale-and-long-term-storage`
- **Curso:** `prometheus-grafana`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `obs-10-promql-advanced-recording-rules-cardinality`.

## Objetivo

Escalar la observabilidad de métricas **más allá de un Prometheus single-node**: entender los límites prácticos (RAM, retención, cardinalidad), las estrategias de **sharding** y **federation**, el modelo `remote_write`, y las tres opciones de long-term store open-source (**Thanos**, **Grafana Mimir**, **VictoriaMetrics**). Al terminar debes poder **elegir, defender y configurar** un long-term store para una organización concreta y estimar sus **costos**.

## Alcance

- Límites prácticos de Prometheus single-node: `RAM ≈ f(series activas)`; retención default 15 d; impacto de WAL y block compaction.
- **Sharding horizontal** por `hashmod` relabel y por `__meta_*` labels (ej. por región / cluster).
- **Federation** clásica (`/federate`, jerárquico) — por qué es frágil y cuándo todavía tiene sentido.
- **`remote_write`** como camino moderno a long-term store: colas, backpressure, formatos (snappy + protobuf; v2 con native histograms).
- **Thanos**: sidecar, store gateway, querier, compactor, ruler; object storage; **downsampling** (5m/1h) y **deduplication** (`replica` label).
- **Grafana Mimir**: arquitectura horizontally-scalable, multi-tenant, distribuidor + ingester + store-gateway + compactor + querier; blocks storage.
- **VictoriaMetrics**: `vmsingle` y `vmcluster` (vmstorage/vminsert/vmselect); muy eficiente en RAM; MetricsQL (compatible PromQL con extensiones); `vmagent` como reemplazo del scrape.
- **Cortex** como predecesor de Mimir y por qué quedó relegado.
- Criterios de elección: operacional, costo, PromQL fidelity, tenancy, soporte comercial.
- **Costos**: storage (object), egress, compute, "active series" como unit económico de referencia.

Lo que **no** cubre (va después o aparte):
- Kube-prometheus-stack en K8s → `obs-12`.
- Loki y logs → `obs-13`.
- SLO/burn-rate → `obs-14`.
- Gobernanza y "cost of observability" en profundidad → `obs-15`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-remote-write-to-victoriametrics/` — compose con Prometheus → VictoriaMetrics single (ejecutable, la opción más ligera).
  - `02-thanos-sidecar-and-querier/` — walkthrough de arquitectura Thanos (sin ejecutar).
  - `03-mimir-helm-overview/` — walkthrough de instalación/arquitectura Mimir con Helm (sin ejecutar).
- **`activities/`**:
  - `01-add-vm-as-long-term-store/` — **guided-lab**: añadir `remote_write` a VictoriaMetrics y verificar con query.
  - `02-adr-thanos-vs-mimir-vs-vm/` — **independent** (architecture): escribir un ADR para una org dada.
- **`resources/links.md`** — docs oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Distinguir federation vs remote_write; explicar por qué `remote_write` serializa muestra a muestra (y su impacto en latencia); describir deduplication y downsampling en Thanos; conocer el modelo de "active series" como unidad de costo. |
| Operativa | Añadir un `remote_write` a Prometheus; validar que las muestras llegan al LTS vía su `/api/v1/query`; configurar un `vmagent` o Prometheus con relabel `hashmod` para sharding; leer un dashboard que combina queries live + históricas. |
| Arquitectónica | Elegir entre Thanos, Mimir y VictoriaMetrics con criterios explícitos; estimar coste de 10M / 100M / 1B samples/día; justificar la decisión en un ADR; diseñar la estrategia de retención (hot / warm / cold) para una org. |

## Criterios de evaluación

- Compose local con Prometheus + VictoriaMetrics corriendo y VM devolviendo series escritas por Prometheus.
- ADR completado con los 3 candidatos, criterios ponderados y decisión defendida.
- Capacidad de calcular retención y coste aproximado para 3 escalas (10M, 100M, 1B samples/día).
- Respuesta argumentada a las preguntas de evaluación de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` entero.
2. Reproduce `examples/01-remote-write-to-victoriametrics/` (ejecutable).
3. Lee `examples/02-thanos-sidecar-and-querier/` y `03-mimir-helm-overview/` (walkthrough).
4. Haz `activities/01-add-vm-as-long-term-store/` (guided).
5. Haz `activities/02-adr-thanos-vs-mimir-vs-vm/` (independent — es la que valida).

## Siguiente

→ `obs-12-prometheus-operator-and-kube-prometheus-stack`.
