# plat-01 — Principios: Team Topologies y Cognitive Load

## Identificación

- **ID:** `plat-01-principles-team-topologies-and-cognitive-load`
- **Curso:** `platform-engineering`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** haber operado un sistema real en producción, y **todos los cursos previos del programa** (`git-and-github` → `otel-14`). Este módulo es la bisagra entre la práctica ingenieril y la **organización** que la hace sostenible.

## Objetivo

Interiorizar el **modelo organizacional** que da sentido a Platform Engineering como disciplina. Al terminar deberías poder dibujar la organización de tu empresa (o una ficticia) en **Team Topologies**, identificar los **antipatterns** más comunes, y explicar por qué un *platform team* mal diseñado degrada la propuesta de valor hasta volverse una cola de tickets.

## Alcance

Este módulo cubre:

- **Cognitive load** aplicada a equipos de software: intrinsic, extraneous, germane; por qué sobrecargar a un stream-aligned con decisiones de infraestructura es un impuesto que se paga en features no entregadas.
- **Team Topologies** (Skelton & Pais): los **4 tipos de equipo** — stream-aligned, enabling, platform, complicated-subsystem — y los **3 modos de interacción** — X-as-a-Service, collaboration, facilitating.
- El principio: **un platform team ES X-as-a-Service por default**. Si cada feature exige *collaboration* con la plataforma, la plataforma falló.
- **Conway's Law** y el **reverse Conway maneuver**: la arquitectura técnica es un reflejo de la estructura de comunicación.
- **Antipatterns clásicos**: *ivory tower platform team*, *ticketing-driven ops*, *platform as a dumping ground*, *platform team sin product mindset*.
- Por qué el rol llamado "DevOps engineer" tan frecuentemente falla donde Platform Engineering (como disciplina de producto interno) tiene chance.
- Métricas tempranas de salud del platform team: adopción voluntaria, lead-time de nuevo servicio, cognitive load percibida de stream-aligned teams.

Lo que **no** cubre (se verá después):

- Diseñar un **golden path** concreto → `plat-02`.
- Elegir un **IDP** (Backstage/Port/CNOE) → `plat-03`.
- Modelar el catálogo, templates, scorecards → `plat-04` → `plat-10`.

Este módulo es **100 % conceptual**. No se levanta infraestructura. Las dos actividades son análisis escritos; el único "tooling" es `bash` + un editor Markdown.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-team-topologies-case-study/` — caso de estudio comentado de una org ficticia (NimbusCo) con 6 equipos y las interacciones mapeadas.
  - `02-cognitive-load-exercise/` — ejercicio guiado para medir cognitive load intrínseca vs extraneous en un equipo stream-aligned concreto.
  - `03-conways-law-walkthrough/` — walkthrough que muestra, con dos escenarios, cómo la estructura de equipos determinó la arquitectura (y cómo un *reverse Conway maneuver* la cambió).
- **`activities/`** — dos actividades **independientes** (sin dependencia entre sí):
  - `01-map-your-org/` — mapear tu organización (real o ficticia) a Team Topologies, con tabla + diagrama + justificación de interacciones.
  - `02-antipattern-identification/` — identificar antipatterns en 4 situaciones dadas y proponer el movimiento concreto para salir.
- **`resources/links.md`** — referencias oficiales (libro, charlas, patterns).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Definir los 4 tipos de equipo y 3 modos de interacción sin ambigüedad. Explicar por qué el *default* de interacción con el platform team es *X-as-a-Service*. |
| Operativa (sin infra) | Dado un organigrama, mapear cada equipo a su tipo Team Topologies y justificarlo. Detectar los 4 antipatterns más comunes. |
| Arquitectónica | Argumentar un *reverse Conway maneuver* concreto para alinear equipos con la arquitectura objetivo. Defender por qué una *platform ticket queue* degrada el valor. |

## Criterios de evaluación

- Dibuja la organización en Team Topologies con los **4 tipos** representados o justificados.
- Identifica al menos **3 antipatterns** y propone el movimiento concreto para corregirlos.
- Justifica por qué un "platform ticket queue" degrada la propuesta de valor del platform team.
- Articula qué debería medir el platform team como *producto interno* (no como *proveedor de tickets*).
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- **Mapa Team Topologies** de una organización dada (sale de la actividad `01-map-your-org`).
- **Lista de antipatterns identificados** con movimiento correctivo (sale de `02-antipattern-identification`).

## Siguiente módulo

→ `plat-02-golden-paths-paved-roads-and-developer-experience` — pasar del modelo organizacional al diseño de "caminos felices" opinionados.
