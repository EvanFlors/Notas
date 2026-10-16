# plat-11 — Métricas DORA, SPACE y Platform-as-a-Product

## Identificación

- **ID:** `plat-11-metrics-dora-space-and-platform-as-product`
- **Curso:** `platform-engineering`
- **Nivel:** producción
- **Duración estimada:** 4 h
- **Prerrequisitos:** `plat-01` (Team Topologies), `plat-02` (Golden Paths), `plat-10` (Scorecards).

## Objetivo

Medir la plataforma **como se mide un producto**. Al terminar deberías poder (a) calcular las cuatro métricas **DORA** a partir de eventos reales de CI/CD, (b) complementarlas con **SPACE** para capturar lo que DORA no ve, y (c) justificar un dashboard de plataforma defendible frente a dos críticas típicas: *vanity metrics* y *Goodhart's Law*.

## Alcance

Este módulo cubre:

- Las cuatro **DORA metrics** actuales (según el *Accelerate State of DevOps Report*): **lead time for changes**, **deployment frequency**, **change failure rate**, **failed deployment recovery time** (ex *time to restore service*).
- Cómo **derivarlas** desde eventos reales de CI/CD: timestamps de GitHub Actions runs, eventos `Sync`/`OutOfSync` de Argo CD, incidents de PagerDuty.
- El framework **SPACE** (Satisfaction, Performance, Activity, Communication/collaboration, Efficiency/flow) y por qué nace como respuesta explícita al uso ingenuo de DORA.
- **Platform NPS** y **adoption metrics** (templates usados, servicios registrados, DB provisionadas via self-service, time-to-first-production).
- **Leading vs lagging indicators** y por qué una plataforma necesita ambos.
- **Platform-as-a-product**: roadmap, backlog priorizado por valor, releases, release notes, feedback groups, user interviews, canvas producto.
- **Financiamiento**: showback vs chargeback, platform fee, por qué una plataforma mal financiada muere.
- Antipatterns: celebrar número de deploys sin cambio de calidad, *survivorship bias* en NPS, metrics-as-weapon vs metrics-as-conversation.

Lo que **no** cubre (otros módulos):

- Scorecards de servicios (`plat-10`).
- Gobernanza multi-tenant y platform SLOs (`plat-12`).
- Instrumentación de aplicaciones (`opentelemetry`, `prometheus-grafana`).

Este módulo es **mayormente conceptual** con un componente de scripting ligero: dos pequeños programas Python que computan DORA desde un `deployment-events.json` sintético y producen un resumen en Markdown. **No** se levanta Argo CD, ni Backstage, ni PagerDuty.

## Materiales

- **`theory/lesson.md`** — lección profunda (12 secciones): DORA, SPACE, NPS, adoption, platform-as-product, financiamiento, antipatterns.
- **`examples/`** — ejemplos demostrativos (lectura y ejecución corta):
  - `01-dora-from-ci-cd-events/` — un `events.json` sintético y un `compute_dora.py` que calcula las 4 métricas. Lectura comentada paso a paso.
  - `02-space-survey-template/` — plantilla YAML/Markdown de encuesta SPACE trimestral: 5 bloques, 20 preguntas, mezcla cuantitativa + cualitativa.
  - `03-platform-product-roadmap/` — ejemplo de roadmap trimestral de plataforma: *now / next / later*, backlog priorizado, release notes.
- **`activities/`** — dos actividades **independientes**:
  - `01-build-dora-dashboard/` — generar un `deployment-events.json` sintético, computar DORA con un script Python, escribir `DORA.md` interpretando los resultados y justificando el *bucket* (Elite/High/Medium/Low) de la organización simulada.
  - `02-platform-product-canvas/` — redactar `CANVAS.md` tratando la plataforma del capstone como un producto: visión, usuarios, propuesta de valor, roadmap trimestral *now/next/later*, financiamiento, 7 métricas elegidas con justificación anti-Goodhart.
- **`resources/links.md`** — DORA report, SPACE paper, Team Topologies, Humanitec report, enlaces canónicos.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Enumerar las 4 DORA metrics con su definición vigente. Explicar en una frase por qué SPACE existe. Distinguir *vanity metric* de métrica accionable. |
| Operativa | Calcular DORA desde un JSON de eventos (deploys, incidents) con un script Python de ~100 líneas. Mapear el resultado al *bucket* (Elite/High/Medium/Low) del DORA report. |
| Arquitectónica | Diseñar un dashboard de plataforma de 8–10 widgets que combine DORA + SPACE + adoption + NPS. Defenderlo contra la crítica "más deploys ≠ mejor producto". Justificar el modelo de financiamiento (showback/chargeback/fee). |

## Criterios de evaluación

- Define las 4 DORA metrics sin confundir *lead time for changes* con *cycle time* o *lead time to market*.
- Explica por qué *change failure rate* por sí sola es insuficiente (necesita *failed deployment recovery time* como contrapeso).
- Nombra las 5 dimensiones de SPACE y da un ejemplo de métrica por dimensión.
- Dado un dashboard con "número de deploys" como único KPI, lo critica citando Goodhart.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- `DORA.md` con las 4 métricas computadas, el *bucket* asignado y la interpretación (sale de la actividad 01).
- `CANVAS.md` platform-as-product con 7 métricas defendidas (sale de la actividad 02).

## Siguiente módulo

→ `plat-12-governance-at-scale-multi-tenant-deprecations-platform-slos` — gobernar la plataforma a escala sin volverse jaula ni caos.
