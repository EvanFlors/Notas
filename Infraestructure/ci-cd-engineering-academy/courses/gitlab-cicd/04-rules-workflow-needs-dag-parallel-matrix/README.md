# gl-04 — Rules, workflow, needs/DAG y parallel:matrix

## Identificación

- **ID:** `gl-04-rules-workflow-needs-dag-parallel-matrix`
- **Curso:** `gitlab-cicd`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `gl-02` (anatomía de `.gitlab-ci.yml` y runners).

## Objetivo

Controlar **cuándo** corre un pipeline y **cuándo** corre cada job, y modelar las dependencias reales entre jobs como un **DAG** en lugar de un pipeline lineal por stages. Al terminar deberías poder:

- Escribir un bloque `workflow:` top-level que filtre pipelines por `$CI_PIPELINE_SOURCE`, branch o estado de MR.
- Reescribir `only/except` (legacy) como `rules:` con `if:`, `changes:` y `exists:`.
- Convertir un pipeline lineal con stages a uno con `needs:` que corte el *wall clock*.
- Expandir una matriz de pruebas multi-dimensión con `parallel: matrix:` y leer `CI_NODE_INDEX`/`CI_NODE_TOTAL`.

## Alcance

Este módulo cubre:

- **`workflow:` top-level**: filtra el pipeline entero antes de evaluar jobs (evita duplicados MR + branch, filtra por `$CI_PIPELINE_SOURCE`, `$CI_COMMIT_BRANCH`, `$CI_MERGE_REQUEST_IID`).
- **`rules:` por job**: reemplazo moderno de `only/except`. Soporta `if:`, `changes:`, `exists:`, `when:` y `allow_failure:` por regla.
- **`when:`** en reglas y en jobs: `on_success`, `on_failure`, `always`, `manual`, `delayed:`.
- **`needs:`** como constructor de **DAG** (los jobs no esperan al stage, sólo a sus dependencias reales).
- **`parallel: N`** y **`parallel: matrix:`** para expandir un job en N instancias por combinación. Uso de `CI_NODE_INDEX`/`CI_NODE_TOTAL`.
- Mención de **child/parent pipelines** (`trigger: include:`) como siguiente paso cuando el DAG se vuelve inmanejable (se profundiza en `gl-05`).

Lo que **no** cubre:

- CI/CD Components y `include:` avanzado → `gl-05`.
- Executors (K8s, Fleeting) y OIDC a cloud → `gl-06`.
- Environments y Review Apps (que suelen combinarse con `rules:`) → `gl-07`.

Este módulo es **mayoritariamente edición de YAML + validación estructural**. **No** se provisiona ni se corre un runner real. Las dos actividades producen un `.gitlab-ci.yml` validado con Python/`yaml` y una pequeña suite estructural en Bash.

## Materiales

- **`theory/lesson.md`** — lección con las 5 piezas (`workflow`, `rules`, `when`, `needs`, `parallel:matrix`) y por qué el DAG mejora el wall clock.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución real contra un runner):
  - `01-workflow-rules/` — `workflow:` que evita duplicar pipelines MR + branch y filtra por `$CI_PIPELINE_SOURCE`.
  - `02-dag-with-needs/` — pipeline lineal convertido a DAG; comparación visual del wall clock antes/después.
  - `03-parallel-matrix/` — matriz 2×3 de tests con `parallel: matrix:` y lectura de `CI_NODE_INDEX`.
- **`activities/`** — dos actividades **independientes**:
  - `01-port-matrix-from-gha/` — portar una matriz de GitHub Actions (`strategy.matrix` 2×3) a GitLab (`parallel: matrix:`) manteniendo las exclusiones y los `include:`. **guided-lab**.
  - `02-cut-wall-clock-with-needs/` — tomar un pipeline con 6 jobs en 3 stages y reescribirlo con `needs:` justificando la ganancia de wall clock. **independent**.
- **`resources/links.md`** — referencias oficiales y comparativas GHA ↔ GitLab.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `rules:` reemplaza a `only/except`, y qué problema concreto resuelve `workflow:` (double pipelines en MR). |
| Operativa (sin runner) | Escribir `.gitlab-ci.yml` con `rules:`, `needs:` y `parallel: matrix:` que parsee limpio y pase el validador estructural. |
| Arquitectónica | Diagnosticar un pipeline con stages lineales e identificar qué `needs:` cortarían el wall clock. |

## Criterios de evaluación

- Dado un `.gitlab-ci.yml` con `only/except`, lo reescribes con `rules:` equivalentes.
- Dado un pipeline con 3 stages y 6 jobs independientes, dibujas el DAG con `needs:` y estimas la mejora de wall clock.
- Dado un `strategy.matrix` de GHA (con `include:` y `exclude:`), lo portas a `parallel: matrix:` sin perder combinaciones.
- Entregas las dos actividades con sus validadores estructurales en verde.

## Entregables

- Un `.gitlab-ci.yml` con `parallel: matrix:` equivalente al `strategy.matrix` del enunciado (actividad `01`).
- Un `.gitlab-ci.yml` con `needs:` que modela el DAG y un `WALL-CLOCK.md` cuantificando la ganancia (actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos YAML y Markdown. No se requiere cuenta de GitLab ni runner activo. Herramientas: `bash`, `python3` con `PyYAML`.

## Siguiente módulo

→ `gl-05-reuse-include-extends-and-cicd-components` — reutilizar lógica con `extends:`, `include:` y CI/CD Components publicados en el Catalog.
