# gh-06 — Rebase vs merge e interactivo

## Identificación

- **ID:** `gh-06-rebase-vs-merge-and-interactive`
- **Curso:** `git-and-github`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `gh-03-branching-and-merging-basics`.

## Objetivo

Dominar `git rebase` (lineal e interactivo) y adquirir **criterio** para elegir entre merge y rebase según el equipo, la rama y la política de historia. Al terminar deberías poder limpiar una rama antes de abrir PR, mover commits entre bases con `--onto`, separar un commit grande y justificar la decisión merge vs rebase en diferentes contextos.

## Alcance

- `git rebase <base>` (lineal, no interactivo).
- `git rebase -i` con todas las acciones: `pick`, `reword`, `edit`, `squash`, `fixup`, `drop`, `exec`, `break`.
- `git commit --fixup=<hash>` + `git rebase -i --autosquash`.
- `git rebase --onto <newbase> <upstream> [<branch>]` para mover un rango de commits a otra base.
- `git cherry-pick <commit>` (en relación con rebase).
- `git rerere` para reutilizar resoluciones de conflicto.
- `git rebase --update-refs` (Git ≥ 2.38) para actualizar ramas intermedias de una stack.
- La **regla de oro**: *no reescribas historia pública*.
- Red de seguridad: `git reflog` + `--force-with-lease` (nunca `--force` a secas).
- Automatizar rebases interactivos en scripts con `GIT_SEQUENCE_EDITOR`.

Lo que **no** cubre (va después):
- Estrategias de "merge" en GitHub (squash and merge / rebase and merge / merge commit) → `gh-07`.
- Modelos de branching (trunk-based, GitHub Flow, GitFlow) → `gh-08`.
- Internals de objetos y por qué cambian los hashes a bajo nivel → `gh-09`.
- Recuperación avanzada (`reflog` como herramienta de forense) → `gh-10`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones (DAGs ASCII incluidos).
- **`examples/`**:
  - `01-interactive-cleanup/` — walkthrough de `pick` / `reword` / `squash` / `fixup` / `drop` sobre un historial sucio.
  - `02-rebase-onto/` — walkthrough de `--onto` para mover una rama de base equivocada a `main`.
- **`activities/`**:
  - `01-squash-and-reorder/` — **guided-lab**: toma una rama con 5 commits WIP y produce 2 commits limpios usando `rebase -i` + `squash`/`fixup`/`reword`. Automatiza con `GIT_SEQUENCE_EDITOR` para que sea reproducible.
  - `02-rebase-onto-wrong-base/` — **independent**: una rama fue creada desde la base equivocada; muévela a `main` con `rebase --onto` sin perder commits ni duplicarlos.
- **`resources/links.md`** — documentación oficial y referencias.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `rebase` reescribe hashes (nuevo parent → nuevo commit); diferenciar `merge` (dos padres, mantiene DAG) de `rebase` (lineal, un padre); describir qué significa "perder información" (padres originales) y cómo `reflog` mitiga el riesgo. |
| Operativa | Reordenar, combinar y descartar commits con `rebase -i`; mover commits entre bases con `--onto`; usar `--autosquash` para fixups semi-automáticos; recuperar con `reflog` tras un rebase fallido; pushear reescrituras con `--force-with-lease`. |
| Arquitectónica | Argumentar merge vs rebase para distintos equipos (trunk-based vs feature branches largas), elegir estrategia por tipo de rama (feature / release / main), diseñar una política de "quién puede reescribir qué". |

## Criterios de evaluación

- Puedes reducir una rama de 5+ commits a 2 commits limpios con `rebase -i` siguiendo un plan explícito (no al azar).
- Puedes mover una rama de 3 commits de base `X` a base `Y` con un único `rebase --onto`.
- Puedes justificar, con argumentos, por qué un equipo adopta "rebase and merge" vs "merge commit" en GitHub.
- Nunca propones `git push --force` donde `--force-with-lease` resolvería el problema.
- Reconoces y evitas el antipatrón de rebasar ramas públicas / `main`.

## Secuencia recomendada

1. Lee `theory/lesson.md` entera.
2. Reproduce `examples/01-interactive-cleanup/`.
3. Haz `activities/01-squash-and-reorder/` (guided).
4. Lee `examples/02-rebase-onto/`.
5. Haz `activities/02-rebase-onto-wrong-base/` (independent — la que valida).
6. Entregable: en un repo cualquiera, abre dos ramas sobre el mismo cambio: una la mergeas con merge commit, otra la rebasas; compara `git log --graph --oneline`.
7. Responde las preguntas de evaluación de `theory/lesson.md`.

## Siguiente

→ `gh-07-collaboration-prs-and-review` (ahí verás cómo GitHub aplica estas estrategias en PRs).
