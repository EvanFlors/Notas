# obs-14 — SLO y burn-rate alerts

## Identificación
- **ID:** `obs-14-slo-and-burn-rate-alerts`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `obs-09-alertmanager-and-alert-design`, `obs-10-promql-advanced-recording-rules-cardinality`, `obs-12-prometheus-operator-and-kube-prometheus-stack`

## Objetivo
Definir SLIs y SLOs para un servicio y alertar sobre la quema del error budget con rigor (multi-window multi-burn-rate), evitando el ruido típico de las alertas single-window y conectando el budget con decisiones de release.

## Temas y subtemas
1. **SLI** — métricas que modelan la experiencia del usuario:
   - *availability* (ratio de peticiones buenas sobre total),
   - *latency* (fracción de peticiones por debajo de un umbral),
   - *correctness* (fracción con resultado correcto),
   - *freshness* (edad del dato por debajo de un umbral).
2. **SLO** — objetivo numérico + ventana (p. ej. 99.9 % en 30 días rolling).
3. **Error budget** — complemento del SLO (`1 - SLO`). Es "gasto permitido" en la ventana.
4. **Burn-rate** — tasa relativa de consumo del budget: `burn_rate = error_rate / (1 - SLO)`.
5. **Single-window** — por qué es ruidoso o lento (sensibilidad vs tiempo-a-alerta).
6. **Multi-window multi-burn-rate (MWMBR)** — doble ventana (larga + corta) con doble umbral; recetas del SRE Workbook.
7. **Recording rules como "ingredientes SLO"** — pre-calcular `sli:*:ratio_rate5m`, `sli:*:ratio_rate1h`, etc.
8. **Herramientas** — `Sloth` y `OpenSLO` para generar reglas y alertas desde una especificación declarativa.
9. **Error budget policy** — qué pasa cuando se agota: freeze de features, foco a reliability, SRE on-call escalation.
10. **SLOs del capstone** — ejemplos concretos para la API del programa.

## Conceptos internos (fundamentos)
- `burn_rate = error_rate / (1 - SLO)`: expresa a cuántas "SLO" por segundo se está consumiendo budget. Burn-rate = 1 agota el budget exactamente al llegar al fin de la ventana.
- **Elegir pares (ventana larga, ventana corta, burn-rate)** calibra "tiempo-a-detectar" y "tiempo-a-recuperar" sin perder precisión. El Workbook recomienda:
  - Severidad página (fast burn): `2 % del budget en 1 h` + `2 % del budget en 5 min` → burn-rate ≥ 14.4.
  - Severidad ticket (slow burn): `5 % del budget en 6 h` + `5 % del budget en 30 min` → burn-rate ≥ 6.
- La ventana corta como "guardia" evita alertas que persisten tras la recuperación.
- Las recording rules evitan recalcular los ingredientes caros en cada regla de alerta y en cada panel.

## Competencias
- **Conceptual:** distinguir SLI de SLO; justificar MWMBR vs single-window; derivar burn-rate.
- **Operativa:** escribir `PrometheusRule` con ingredientes + alertas MWMBR; validar con `promtool`; generar con Sloth.
- **Arquitectónica:** incorporar error budget al proceso (release gating, freeze policy); evaluar cuándo bajar o subir un SLO.

## Ejemplos
- [`examples/01-slo-ingredients-recording-rules`](examples/01-slo-ingredients-recording-rules/) — Recording rules que precomputan los SLIs sobre ventanas múltiples.
- [`examples/02-mwmbr-alert`](examples/02-mwmbr-alert/) — Alertas MWMBR para severidad página y severidad ticket.
- [`examples/03-sloth-generate`](examples/03-sloth-generate/) — Generación de reglas desde una spec Sloth YAML (con fallback si Sloth no está disponible).

## Actividades
- [`activities/01-define-capstone-slos`](activities/01-define-capstone-slos/) — Guided lab: definir SLO formal del capstone, escribir ingredientes y MWMBR a mano, validar con `promtool`.
- [`activities/02-adopt-sloth`](activities/02-adopt-sloth/) — Independent: generar las mismas reglas con Sloth y compararlas con la versión escrita a mano.

## Entregables
- SLO formal (SLI, objetivo, ventana, consecuencias) para al menos un servicio del capstone.
- `PrometheusRule` con ingredientes + alertas MWMBR validados por `promtool test rules`.
- `slo.yaml` consumible por Sloth (y la salida de `sloth generate` comparada).

## Criterios de evaluación
- **Conceptual:** explicar por qué single-window es ruidoso o lento; relacionar burn-rate con porcentaje de budget consumido.
- **Operativa:** reglas pasan `promtool check rules` y `promtool test rules` (fixtures incluidos).
- **Arquitectónica:** la política documentada define qué ocurre al agotar el budget (freeze, revert, escalation) y cuándo renegociar el SLO.

## Recursos
Ver [`resources/links.md`](resources/links.md).
