# helm-06 — Dependencias y umbrella charts

## Identificación

- **ID:** `helm-06-dependencies-and-umbrella-charts`
- **Curso:** `helm`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `helm-05-values-precedence-and-child-charts`.

## Objetivo

Componer charts con dependencias correctamente: declararlas, pinearlas con `Chart.lock`, activarlas/desactivarlas con `condition:` y decidir con criterio cuándo un **umbrella chart** es la respuesta correcta y cuándo es una trampa que acopla lifecycles de equipos distintos.

## Alcance

Este módulo cubre:

- `dependencies:` en `Chart.yaml` v2 (`name`, `version`, `repository`, `alias`, `condition`, `tags`, `import-values`).
- `helm dependency update` vs `helm dependency build` y el rol de **`Chart.lock`**.
- Alias (`alias:`) para montar el mismo subchart dos veces (p. ej. `primary` + `replica`).
- Condicionales (`condition: foo.enabled`) y `tags: [...]`.
- **Umbrella chart** vs **chart por app**: ventajas, costes y cuándo cada uno.
- Cuándo **no** usar umbrella: lifecycle acoplado entre equipos, blast radius grande, upgrade atómico forzado.
- Disciplina de versionado de dependencias: SemVer, lockfile, renovación controlada.

Lo que **no** cubre (se verá después):

- Hooks y `--atomic` en el ciclo de la release → `helm-07`.
- Firma y publicación OCI de charts con deps → `helm-08`.
- `library charts` (`type: library`) → `helm-10`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-add-postgres-as-dependency/` — chart que declara `bitnami/postgresql` como dep (requiere internet).
  - `02-conditional-dependency/` — mismo chart con `condition:` para activar/desactivar la DB.
  - `03-chart-lock-reproducibility/` — qué fija `Chart.lock`, qué cambia entre `update` y `build`.
- **`activities/`**:
  - `01-umbrella-for-dev-stack/` — guided lab: umbrella que empaqueta app + Postgres para dev local.
  - `02-split-umbrella-decision/` — independiente: redactar ADR que defienda umbrella vs separación en 3 escenarios reales.
- **`resources/links.md`** — documentación oficial verificable.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué fija `Chart.lock` y qué pasa sin él. Diferenciar `dependency update` de `dependency build`. Describir qué es un umbrella chart en términos de releases y revisiones. |
| Operativa | Añadir una dep remota, pinearla con lock, activarla con `condition:`, montar un subchart con `alias:`, consumir valores del subchart a través de `global:`. |
| Arquitectónica | Decidir con argumentos umbrella vs charts separados para un escenario dado, considerando ownership, lifecycle y blast radius. Diseñar la frontera de un chart compuesto sin acoplar equipos. |

## Criterios de evaluación

- Chart umbrella funcional para dev local que levanta la app con Postgres como subchart.
- `Chart.lock` presente y commiteado; versiones pinneadas con SemVer explícito.
- La misma base de chart puede renderizarse con o sin Postgres según `condition:` sin tocar `templates/`.
- ADR que defienda **no** usar umbrella en producción con al menos tres argumentos operacionales (lifecycle, ownership, blast radius).
- Respuesta argumentada a los 3 escenarios de evaluación.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-add-postgres-as-dependency/` observando `Chart.lock` y `charts/`.
3. Reproduce `examples/02-conditional-dependency/` cambiando el flag.
4. Reproduce `examples/03-chart-lock-reproducibility/` — es el que ancla el "por qué".
5. Haz la actividad `activities/01-umbrella-for-dev-stack/`.
6. Haz la actividad `activities/02-split-umbrella-decision/` sin consultar la lección.
7. Responde las preguntas de evaluación de la lección.

## Siguiente

→ `helm-07-lifecycle-hooks-tests-and-atomic`: controlar el ciclo de instalación/upgrade con hooks, `helm test` y `--atomic`.
