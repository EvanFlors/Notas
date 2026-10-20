# gha-03 — Eventos y triggers

## Identificación

- **ID:** `gha-03-events-and-triggers`
- **Curso:** `github-actions`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** `gha-02-syntax-expressions-and-contexts`.

## Objetivo

Elegir con criterio el **trigger** correcto para cada escenario, entender el **payload** que llega al workflow y evitar la trampa de seguridad más común del ecosistema: `pull_request_target` con checkout del head del PR.

## Alcance

- Triggers de uso diario: `push`, `pull_request`, `workflow_dispatch`, `schedule` (cron en UTC), `release`.
- Triggers de orquestación: `workflow_call`, `workflow_run`, `repository_dispatch`.
- Triggers reactivos del repo: `issues`, `issue_comment`.
- Filtros: `branches`, `branches-ignore`, `tags`, `tags-ignore`, `paths`, `paths-ignore`, `types`.
- Payload del evento (`github.event.*`): qué llega, cómo inspeccionarlo, cuándo es confiable.
- `pull_request` desde forks: por qué los secretos no se exponen por defecto y por qué el `GITHUB_TOKEN` es de solo lectura en PRs externos.
- Diferencia **crítica** entre `pull_request` (checkout del head del PR, sin secretos) y `pull_request_target` (checkout del base, *con* secretos). Patrón seguro cuando se necesita el segundo.
- Comportamiento particular de `workflow_run` (siempre contra el default branch).

Lo que **no** cubre (va después):

- Autoría de actions personalizadas → `gha-12`.
- OIDC a cloud providers → `gha-11`.
- Hardening completo del pipeline → `gha-13`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-paths-filter/` — `push`/`pull_request` que corre solo cuando cambian ciertas rutas.
  - `02-manual-dispatch-with-inputs/` — `workflow_dispatch` con inputs tipados (`string`, `choice`, `boolean`).
  - `03-pull-request-target-safe-pattern/` — plantilla segura para labelear/comentar PRs desde forks sin exponer el token.
- **`activities/`**:
  - `01-trigger-matrix/` — guided-lab: catálogo propio con **≥ 5** triggers distintos y filtros, validado estructuralmente.
  - `02-safe-fork-pr-workflow/` — independiente: construir el patrón de dos workflows (uno con `pull_request` que corre tests sin secretos; otro con `pull_request_target` o `workflow_run` que publica resultados **sin** hacer checkout del código no confiable).
- **`resources/links.md`** — docs oficiales de eventos, filtros y hardening.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar diferencia `pull_request` vs `pull_request_target` en términos de **qué código se checkoutea** y **qué secretos están disponibles**. Describir cuándo se ejecuta un workflow con `workflow_run` y por qué siempre contra el default branch. Leer una expresión cron y predecir cuándo dispara (recordando UTC). |
| Operativa | Diseñar `on:` con los filtros adecuados (`branches`, `paths`, `types`) para que un workflow dispare solo cuando debe. Añadir `workflow_dispatch` con inputs tipados y usarlos desde la UI o `gh workflow run`. Implementar el patrón de dos workflows para PRs de forks sin crear la vulnerabilidad típica. |
| Arquitectónica | Elegir trigger para 5+ escenarios (CI de PR, deploy en tag, limpieza nocturna, bot que responde a comentarios, pipeline manual) justificando por qué los otros no sirven. Dibujar la superficie de ataque de `pull_request_target` mal usado. |

## Criterios de evaluación

- Catálogo propio de triggers (actividad 01) que lista 5+ eventos con filtros, un ejemplo YAML válido para cada uno y 2–3 líneas de "cuándo usarlo".
- Patrón seguro de dos workflows funcional (actividad 02): el workflow con `pull_request_target` **no** hace `actions/checkout` con `ref: ${{ github.event.pull_request.head.sha }}`, y si lo necesita hace split explícito (job sin secretos para checkout + job con secretos sin código del PR).
- Respuesta argumentada a los 5 escenarios de la sección "Evaluación" en `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` entero.
2. Reproduce `examples/01-paths-filter/` y `examples/02-manual-dispatch-with-inputs/`.
3. Haz `activities/01-trigger-matrix/`.
4. Lee con cuidado `examples/03-pull-request-target-safe-pattern/`.
5. Haz `activities/02-safe-fork-pr-workflow/`.
6. Responde los 5 escenarios de evaluación sin consultar.

## Siguiente

→ `gha-04-marketplace-actions-and-basics-of-reuse`.
