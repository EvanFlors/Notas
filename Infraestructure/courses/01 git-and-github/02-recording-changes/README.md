# gh-02 — Recording changes

## Identificación

- **ID:** `gh-02-recording-changes`
- **Curso:** `git-and-github`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `gh-01-setup-and-mental-model`.

## Objetivo

Dominar el ciclo diario: **staging selectivo**, **commits atómicos**, y **deshacer cambios con precisión**. Al terminar, deberías poder tomar un working tree sucio con cambios no relacionados y producir una historia lineal de commits pequeños y temáticos.

## Alcance

- `git add -p` (staging por hunks).
- `git restore`, `git restore --staged`, `git checkout` (uso moderno).
- `git diff` en sus tres variantes (worktree / staged / HEAD).
- `git commit --amend` y qué pasa realmente debajo.
- `.gitignore` y `.gitattributes` (line endings, binary diff).
- Mensajes de commit: discipline + *Conventional Commits* como opción.
- Diferenciación precisa `restore` vs `reset` vs `revert` vs `checkout`.

Lo que **no** cubre (va después):
- Branching, merge, rebase → `gh-03`.
- Rebase interactivo (`squash`, `fixup`) → `gh-06`.
- Reflog, bisect, recovery avanzada → `gh-10`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-staging-selectively/` — demo de `git add -p` sobre un archivo con hunks múltiples.
  - `02-gitignore-patterns/` — patrones comunes, pitfalls y `.gitattributes`.
- **`activities/`**:
  - `01-atomic-commits/` — guided-lab: tomar un diff sucio y producir N commits atómicos.
  - `02-recover-from-mistakes/` — **independent**: serie de estados rotos a recuperar.
- **`resources/links.md`** — docs oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Diferenciar `restore` / `reset` / `revert` / `checkout` sin consultar. Explicar por qué `--amend` **crea un commit nuevo** (el viejo queda dangling). Describir qué es el index como *árbol serializado*. |
| Operativa | Usar `git add -p` para dividir cambios en hunks; `restore` para deshacer en cada área con precisión; `diff` en sus 3 variantes; `--amend` con criterio; `.gitignore` + `.gitattributes` desde el día uno del repo. |
| Arquitectónica | Elegir y defender convención de commits (Conventional Commits u otra) para un equipo. Diseñar `.gitattributes` para equipos multi-OS. Decidir cuándo *amend*, cuándo *fixup commit + rebase*, cuándo *revert*. |

## Criterios de evaluación

- Historia con ≥ 10 commits atómicos y mensajes significativos.
- Capacidad de recuperarse de 4 escenarios "rotos" sin perder trabajo.
- `.gitignore` + `.gitattributes` presentes y correctos en el repo del capstone.
- Respuesta argumentada a las 7 preguntas de evaluación de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md`.
2. Reproduce `examples/01-staging-selectively/`.
3. Haz `activities/01-atomic-commits/` (guided).
4. Lee `examples/02-gitignore-patterns/`.
5. Haz `activities/02-recover-from-mistakes/` (independent — la que valida).
6. Responde las preguntas de evaluación sin consultar.

## Siguiente

→ `gh-03-branching-and-merging-basics`.
