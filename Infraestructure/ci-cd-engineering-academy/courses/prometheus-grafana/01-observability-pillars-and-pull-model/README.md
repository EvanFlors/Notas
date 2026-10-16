# obs-01 — Pilares de observabilidad y modelo pull

## Identificación

- **ID:** `obs-01-observability-pillars-and-pull-model`
- **Curso:** `prometheus-grafana`
- **Nivel:** fundamentos
- **Duración estimada:** 2 h
- **Prerrequisitos:** nociones básicas de HTTP y de sistemas (CPU, memoria, latencia, procesos). No se requiere infraestructura.

## Objetivo

Interiorizar **qué es observabilidad** (y en qué se diferencia del *monitoring* tradicional) y entender **por qué Prometheus eligió el modelo pull**. Al terminar deberías poder justificar la elección de Prometheus para un caso y, con el mismo criterio, decir **cuándo *no* es la respuesta**.

## Alcance

Este módulo cubre:

- La diferencia entre *monitoring* ("mide lo que ya sabes que importa") y *observabilidad* ("permite responder preguntas nuevas sobre tu sistema sin desplegar código").
- Los **tres pilares** (metrics, logs, traces) y los pilares emergentes (events, continuous profiling).
- **Pull vs push**: por qué Prometheus eligió pull, qué le da (service discovery simétrico, auditoría, detección automática de targets caídos vía `up == 0`) y qué le cuesta.
- **Límites del pull**: jobs batch cortos → `Pushgateway` como excepción documentada, no como regla.
- Por qué los **exporters** son el "driver" común del ecosistema Prometheus.
- Por qué Prometheus **no** es un sistema de retención larga ni una base de datos general.

Lo que **no** cubre (se verá después):

- Instalar y correr el stack → `obs-02`.
- Tipos de métricas y naming (`counter`, `gauge`, `histogram`, `summary`) → `obs-03`.
- PromQL → `obs-04`.
- Instrumentación en Python → `obs-07`.

Este módulo es **100% conceptual**. No se levanta infraestructura.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-metrics-logs-traces-mental-model/` — mapa anotado de los tres pilares con la misma incidencia vista por cada uno.
  - `02-pull-vs-push-tradeoffs/` — tabla comparativa anotada y diagramas ASCII.
- **`activities/`** — dos actividades **independientes**:
  - `01-when-not-prometheus/` — análisis: para 4 escenarios dados, decidir si Prometheus es la respuesta correcta y defender la decisión.
  - `02-identify-pillars-in-a-scenario/` — dado un postmortem narrado, mapear qué información necesitó cada pilar.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Definir *observabilidad* en una frase sin recurrir al slogan "los tres pilares". Explicar por qué `scrape failed` es un dato de primera clase. Enumerar los tres pilares y lo que cada uno responde bien. |
| Operativa (sin infra) | Dado un `/metrics` ficticio y una topología, decidir si Prometheus scrapearía ese target y por qué. Identificar en qué pilar vive una pregunta concreta ("¿cuántos 5xx en la última hora?" vs "¿por qué este request falló?"). |
| Arquitectónica | Justificar la elección de Prometheus para un caso y, con el mismo criterio, defender *no* usarlo (p. ej. jobs batch de 10 s, telemetría de IoT masivo, data warehouse). Explicar el rol de Pushgateway como excepción. |

## Criterios de evaluación

- Explica por qué los jobs batch necesitan Pushgateway y por qué el push **no** debe ser el default.
- Distingue monitoring de observabilidad con un ejemplo propio (no copiado de la lección).
- Dado un escenario, propone pilar correcto para cada pregunta de debugging.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- Mapa anotado de los pilares (sale de la actividad 02).
- Notas razonadas sobre el modelo pull (sale de la actividad 01).

## Siguiente módulo

→ `obs-02-install-local-stack-and-first-scrape` (ya con infra: `docker compose up` y primer scrape visible).
