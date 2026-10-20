# plat-03 — Panorama IDP: Backstage, Port, CNOE y vecinos

## Identificación

- **ID:** `plat-03-idp-landscape-backstage-port-cnoe`
- **Curso:** `platform-engineering`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `plat-01` (Team Topologies / cognitive load) y `plat-02` (golden paths / DX). No se instala nada en este módulo.

## Objetivo

Mapear el **panorama actual de herramientas de Internal Developer Platform (IDP)** — **Backstage**, **Port**, **OpsLevel**, **Cortex**, **Humanitec**, **CNOE** — y aprender a **elegir fundadamente** sin caer en la trampa de "Backstage por default". Al terminar deberías poder redactar un ADR de selección defendible frente a presión comercial de un vendor.

## Alcance

Este módulo cubre:

- La **ecología** actual de IDPs: OSS vs SaaS vs reference stack.
- **Backstage** (OSS, Spotify → CNCF): framework Node/TS con catálogo + templates + TechDocs + plugins; implica **construir** un IDP.
- **Port** (SaaS): plataforma configurable con menor requerimiento de ingeniería interna; implica **configurar** un IDP.
- **OpsLevel** y **Cortex**: scorecards-first, enfoque en *service maturity* antes que en portal.
- **Humanitec**: *platform orchestrator* opinionado basado en Score (workload spec abstracto).
- **CNOE** (Cloud Native Operational Excellence): reference stack bendecido por la CNCF, Backstage + Argo CD + Crossplane + Keycloak + Argo Workflows; implica **desplegar** una referencia preensamblada.
- **Criterios de elección**: tamaño del equipo plataforma, presupuesto, deseo de ingeniería interna, grado de opinión, extensibilidad, time-to-first-value, lock-in.
- Los **límites honestos**: ninguna herramienta "resuelve" Platform Engineering por sí sola — son instrumentos, no la disciplina.

Lo que **no** cubre (se verá después):

- Instalar Backstage y entender su arquitectura → `plat-04`.
- Modelar el catálogo → `plat-05`.
- Templates y scaffolder → `plat-06`.
- TechDocs, plugins, self-service infra con Crossplane → `plat-07`, `plat-08`, `plat-09`.

Este módulo es **100 % conceptual y comparativo**. No se levanta infraestructura, no hay contenedores, no hay credenciales. Las dos actividades son análisis escritos tipo **ADR**; el único tooling es `bash` + un editor Markdown.

## Materiales

- **`theory/lesson.md`** — lección con 10 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-tool-matrix/` — matriz comparativa comentada de las 6 herramientas (ejes: modelo de distribución, catálogo, templates, scorecards, extensibilidad, costo, time-to-value).
  - `02-cnoe-overview/` — diagrama ASCII y walkthrough de la reference stack CNOE y cuándo tiene sentido adoptarla.
  - `03-port-vs-backstage/` — comparativa cara a cara Backstage vs Port en 8 dimensiones con el *gotcha* típico de cada opción.
- **`activities/`** — dos actividades **independientes** (sin dependencia entre sí):
  - `01-tool-choice-adr/` — redactar un ADR de selección de IDP para una organización dada, defendiendo la elección contra 3 alternativas.
  - `02-poc-matrix-for-your-org/` — diseñar una **matriz de evaluación PoC** con criterios ponderados para elegir IDP en tu organización real.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Diferenciar "construir vs configurar vs desplegar" un IDP. Enumerar las 6 herramientas y su propuesta de valor en una frase cada una. |
| Operativa (sin infra) | Dado un contexto organizacional (tamaño, presupuesto, stack), seleccionar 2 finalistas razonables y nombrar los criterios decisivos. |
| Arquitectónica | Redactar un ADR de elección defendible y una matriz PoC con criterios ponderados que un lead pueda ejecutar en 2–4 semanas. |

## Criterios de evaluación

- Explica, con palabras propias, la diferencia entre **framework** (Backstage), **SaaS configurable** (Port) y **reference stack** (CNOE).
- Dado un escenario, propone 2 finalistas y descarta razonadamente al resto.
- Defiende la decisión frente a un vendor que presiona por *todas-las-features*.
- Nombra al menos **3 criterios no-tecnológicos** (adopción interna, financiamiento, hiring, deprecations) que pesan tanto como los tecnológicos.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- **ADR de selección de IDP** para el capstone (sale de `01-tool-choice-adr`).
- **Matriz PoC** con criterios ponderados y plan de evaluación 2–4 semanas (sale de `02-poc-matrix-for-your-org`).

## Siguiente módulo

→ `plat-04-backstage-architecture-and-setup` — instalar Backstage, entender `packages/app` + `packages/backend`, auth GitHub y Postgres.
