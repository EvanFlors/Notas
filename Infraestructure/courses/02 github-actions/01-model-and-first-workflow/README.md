# gha-01 — Modelo mental y primer workflow

## Identificación

- **ID:** `gha-01-model-and-first-workflow`
- **Curso:** `github-actions`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** curso `git-and-github` ≥ `gh-07` (push, PRs, remotos). Nociones básicas de YAML. Un editor y Git instalados.

## Objetivo

Construir el **modelo mental correcto** de GitHub Actions —*eventos → workflows → jobs → steps → runners*— y poder leer un workflow ajeno prediciendo exactamente qué va a ocurrir cuando se dispare. Al terminar, debes poder llevar un repo recién creado a tener un pipeline mínimo que corra en `push` y `pull_request` con logs verdes.

## Alcance

Este módulo cubre:

- La cadena **evento → workflow → job → step → runner** y por qué cada eslabón existe.
- Anatomía del archivo YAML: `on`, `jobs`, `runs-on`, `steps`, `name`.
- Convención de ubicación: `.github/workflows/*.yml`.
- La diferencia operacional entre `uses:` (invocar una action empaquetada) y `run:` (ejecutar shell en el runner).
- Qué hace `actions/checkout` y por qué *no* es automático.
- La UI de Actions en GitHub (lista de runs, logs por step, re-run).
- Minutos de cómputo, pricing básico y por qué importa.
- El contexto `github` (quién lo rellena, qué trae).
- Qué es la *runner image* y qué viene preinstalado.

Lo que **no** cubre (vendrá después):
- Expresiones `${{ … }}`, contextos avanzados, `if:`, env a tres niveles → `gha-02`.
- Catálogo profundo de triggers (`pull_request_target`, `workflow_run`, cron, etc.) → `gha-03`.
- Pin a SHA, auditoría de actions del marketplace → `gha-04`.
- Secretos y permisos del `GITHUB_TOKEN` → `gha-05`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones (3 h de lectura + exploración).
- **`examples/`** — ejemplos reproducibles:
  - `01-hello-world/` — workflow mínimo (6 líneas útiles) con walkthrough de cada token.
  - `02-run-vs-uses/` — dos jobs equivalentes, uno con `run:` puro, otro combinando `uses:` + `run:`.
- **`activities/`** — dos actividades (dual-mode `local` | `live`):
  - `01-first-workflow/` — **guided-lab**. Construir un repo con `.github/workflows/ci.yml` mínimo que corra en `push` y `pull_request`.
  - `02-read-and-explain/` — **independent**. Dado un workflow ajeno, predecir orden de steps, qué cambia con la UI de re-run, y qué pasaría si borras `actions/checkout`.
- **`resources/links.md`** — documentación oficial y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la cadena `evento → workflow → job → step → runner` sin consultar. Decir qué hace `actions/checkout` y por qué GitHub no clona el repo automáticamente. Diferenciar `run:` de `uses:`. Reconocer de dónde sale cada campo del contexto `github`. |
| Operativa | Crear un repo con un workflow que se dispare en `push` y `pull_request`, leer sus logs, re-correr un job desde la UI, interpretar el badge/estado de un commit. |
| Arquitectónica | Dado un workflow ajeno, predecir qué ocurrirá paso a paso; detectar antipatterns básicos (olvidar checkout, hardcodear versiones de SO en el `name` en vez de `runs-on`). |

## Criterios de evaluación

- Repo con `.github/workflows/ci.yml` que dispara en `push` y `pull_request`, con al menos un step `actions/checkout` y un `run:` que imprime información útil (versión de SO, de Git, listado del repo).
- Capacidad de leer un workflow dado y predecir el output *antes* de ejecutarlo.
- Explicación verbal (o escrita) de la secuencia completa: push → GitHub recibe evento → scheduler encola run → runner levanta VM → ejecuta jobs → publica logs → commit queda con un check verde o rojo.
- `tests/validate.sh` de cada actividad pasa.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin consultar nada externo).
2. Reproduce `examples/01-hello-world/` y luego `examples/02-run-vs-uses/`.
3. Haz la actividad `01-first-workflow/` en `MODE=local` (sin cuenta GitHub) y, si tienes `gh auth`, en `MODE=live` también.
4. Haz la actividad `02-read-and-explain/` sin consultar la solución — es la que valida comprensión real.
5. Responde las preguntas de evaluación de la lección sin re-leer.

## Siguiente

→ `gha-02-syntax-expressions-and-contexts`: expresiones `${{ … }}`, contextos (`github`, `env`, `vars`, `secrets`, …), `if:` condicional, interpolación segura vs inyección de scripts.
