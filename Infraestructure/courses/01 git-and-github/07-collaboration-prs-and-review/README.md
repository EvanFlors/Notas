# gh-07 — Colaboración vía Pull Requests y revisiones

## Identificación

- **ID:** `gh-07-collaboration-prs-and-review`
- **Curso:** `git-and-github`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `gh-05-github-first-contact`, `gh-06-rebase-vs-merge-and-interactive`.

## Objetivo

Colaborar vía **Pull Requests** con **revisiones efectivas**: abrir PRs claros, dar feedback útil, aplicar políticas razonables (templates, CODEOWNERS, required reviewers, auto-merge) y **elegir conscientemente** entre `merge commit` / `squash and merge` / `rebase and merge` según la historia que quieres construir.

## Alcance

Este módulo cubre:

- Modelo PR en GitHub: fork vs. branch-based workflow; cuándo cada uno.
- Qué **es** un PR en términos de refs: `refs/pull/<N>/head` y `refs/pull/<N>/merge`.
- Draft PRs, Ready for review, review tools (comments de línea, suggestions, approve/request changes).
- Linked issues y keywords de cierre automático (`Fixes #N`, `Closes #N`, `Resolves #N`).
- `PULL_REQUEST_TEMPLATE.md` (único o múltiple por tipo).
- `CODEOWNERS`: sintaxis, orden de precedencia, ownership por path/glob.
- Required reviewers (vía protección de rama o Rulesets) y auto-merge.
- Las tres estrategias de merge y qué commit crea GitHub en cada una.
- Cómo evitar scope creep y escribir descripciones que un reviewer pueda cargar en 90 s.

Lo que **no** cubre (se verá después):
- Rulesets completos, environments, OIDC, GitHub Apps → `gh-12`.
- Workflows (trunk vs. GitFlow) → `gh-08`.
- Firmas de commits y supply chain → `gh-13`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos:
  - `01-pr-template/` — plantilla única + plantillas múltiples por tipo bajo `.github/PULL_REQUEST_TEMPLATE/`.
  - `02-codeowners/` — `CODEOWNERS` con tres niveles de granularidad (default + path + glob) y comentarios.
- **`activities/`** — dos actividades guided-lab, con **doble modo** (`live` y `local`):
  - `01-open-review-merge-pr/` — simular/abrir un PR, templarlo, revisarlo, y mergearlo con una estrategia justificada.
  - `02-codeowners-and-required-reviews/` — redactar un `CODEOWNERS` y un PR template válidos para un repo multi-equipo.
- **`resources/links.md`** — referencias verificables.

## Modos de ejecución

Las actividades están diseñadas para ejecutarse **sin cuenta de GitHub**:

- `MODE=local` (default): usa un **bare repo** local como "remoto" y archivos convencionales (`.pr/`, `.github/`) para simular PR, review y merge. Los validadores corren en CI sin credenciales.
- `MODE=live`: usa `gh pr create`, `gh pr review`, `gh pr merge`. Requiere `gh auth login` y un repo en GitHub propiedad del estudiante.

Cada `tests/validate.sh` detecta `$MODE` y aplica los checks apropiados.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué refs crea GitHub al abrir un PR. Describir qué commit produce cada estrategia de merge (merge commit, squash, rebase) y qué pierde o conserva. Distinguir `CODEOWNERS` de "required reviewers". |
| Operativa | Abrir un PR con título claro, descripción cargable en 90 s, issues linkeados, y una checklist de verificación. Dar y recibir reviews con *suggestions* y *request changes* sin fricción. Mergear con la estrategia correcta para el repo. |
| Arquitectónica | Elegir la estrategia de merge (y la política de reviewers) coherente con el *tipo de historia* del repo (lineal, con contexto, con cuadriculado de merges). Justificar fork-based vs. branch-based para un proyecto dado. |

## Criterios de evaluación

- Repo con `.github/PULL_REQUEST_TEMPLATE.md` útil, no decorativo.
- Repo con `CODEOWNERS` que efectivamente dispara reviewers en patrones representativos.
- Al menos un PR abierto, revisado (comment + suggestion + approve o request changes) y mergeado, con **estrategia de merge justificada** en la descripción.
- Respuesta argumentada a las preguntas de evaluación de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada).
2. Revisa `examples/01-pr-template/` y `examples/02-codeowners/`.
3. Haz `activities/01-open-review-merge-pr/` en `MODE=local` para interiorizar el flujo sin fricción de red.
4. Repítela en `MODE=live` si tienes `gh auth login`.
5. Haz `activities/02-codeowners-and-required-reviews/`.
6. Responde la evaluación.

## Siguiente

→ `gh-08-workflows-trunk-vs-gitflow`: enmarcar PRs y reviews dentro de un modelo de ramificación coherente.
