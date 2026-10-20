# plat-02 — Golden paths, paved roads y Developer Experience

## Identificación

- **ID:** `plat-02-golden-paths-paved-roads-and-developer-experience`
- **Curso:** `platform-engineering`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** `plat-01-principles-team-topologies-and-cognitive-load`.

## Objetivo

Diseñar **"caminos felices" opinionados** sin anular la innovación. Al terminar deberías poder (a) definir qué es un *golden path* y en qué se diferencia de un *paved road* y de un **mandato**; (b) proponer y defender un primer golden path con criterios explícitos; y (c) medir **Developer Experience (DX)** con métricas que no se gamifiquen por sí solas.

## Alcance

Este módulo cubre:

- **Definición operativa** de **golden path**: camino preferido, soportado por el platform team, con la mejor DX y documentado como producto.
- **Netflix "paved road"**: el mismo concepto con fuerte compromiso de **ownership** y de operación "en nombre del usuario".
- Diferencia clave: **golden path = opt-in** (hay salida) vs **mandato = forzado** (política, policy-as-code).
- **Criterios para elegir el primer path**: volumen de casos, variabilidad baja, dolor compartido, impacto medible, bajo riesgo de regresión.
- **DX como métrica**: `time-to-first-commit`, `time-to-production` (TTP), tasa de errores de onboarding, platform **NPS**, tickets evitados.
- El **long tail**: cómo tratar servicios/casos que **no** entran en el path (opción B *soportada* vs *no soportada*).
- **Evolución y deprecations**: cómo deprecar un path sin romper el ecosistema.
- **Feedback loops explícitos**: entrevistas (DX interviews), surveys y telemetría de uso.

Lo que **no** cubre (se verá después):

- Herramientas IDP concretas (Backstage, Port, CNOE) → `plat-03`.
- Construir y mantener templates ejecutables → `plat-06`.
- Scorecards y madurez → `plat-10`.
- Métricas DORA/SPACE a nivel organización → `plat-11`.

Este módulo es **100 % conceptual**. No se levanta infraestructura. Las dos actividades son análisis escritos; el único *tooling* es `bash` + un editor Markdown.

## Materiales

- **`theory/lesson.md`** — lección con 10 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-netflix-paved-road-reading/` — resumen anotado del modelo "paved road" de Netflix y qué transferir / qué no.
  - `02-first-golden-path-canvas/` — canvas plantilla del "primer golden path" con secciones mínimas.
  - `03-dx-metrics-samples/` — ejemplos de métricas DX con fórmulas y antipatterns (gaming, Goodhart).
- **`activities/`** — dos actividades **independientes**:
  - `01-define-first-golden-path/` — rellenar el canvas del golden path **"nuevo microservicio Python"**.
  - `02-dx-interview-template/` — diseñar la plantilla de entrevista DX para 5 developers del capstone.
- **`resources/links.md`** — referencias.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Distinguir *golden path*, *paved road* y *mandato*. Nombrar 4–6 métricas DX y explicar en qué se pueden gamificar. |
| Operativa (sin infra) | Rellenar un canvas de golden path candidato con criterios defendibles y una "opción B" para el long tail. |
| Arquitectónica | Diseñar un feedback loop explícito (entrevistas + survey + telemetría) con cadencia y responsables. |

## Criterios de evaluación

- Explica, con palabras propias, por qué un **mandato sin golden path previo** suele fallar.
- Nombra 4–6 **métricas DX** y para cada una un *failure mode* (cómo se puede gamificar o cómo degenera).
- Dado un golden path cándido, identifica si trata bien el **long tail** o no.
- Diseña una entrevista DX con preguntas abiertas (no "¿te gusta la plataforma?").
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- Canvas del golden path **"nuevo microservicio Python"** del capstone (sale de la actividad `01-define-first-golden-path`).
- Plantilla reutilizable de **DX interview** (sale de la actividad `02-dx-interview-template`).

## Siguiente módulo

→ `plat-03-idp-landscape-backstage-port-cnoe` — mapear el panorama de herramientas IDP y elegir fundamentadamente.
