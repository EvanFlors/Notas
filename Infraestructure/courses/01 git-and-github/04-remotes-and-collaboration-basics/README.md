# gh-04 — Remotes and collaboration basics

## Identificación

- **ID:** `gh-04-remotes-and-collaboration-basics`
- **Curso:** `git-and-github`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `gh-03-branching-and-merging-basics`.

## Objetivo

Entender el **modelo distribuido** de Git: cómo un repo local se comunica con otro repo (local o remoto) mediante `clone`, `fetch`, `pull` y `push`; qué son las **tracking branches** (`origin/main`); por qué `fetch` es seguro y `pull` puede sorprender; cómo Git protege contra escrituras destructivas con la regla de **fast-forward**.

Al terminar deberías poder operar una colaboración completa **sin GitHub**, usando únicamente un **bare repo local** como "servidor".

## Alcance

- `git remote add/-v/rename/remove`.
- Protocolos (SSH, HTTPS, file, `git://`) — por qué SSH es el estándar práctico.
- `git clone` (shallow, bare, mirror — mención).
- `refs/remotes/<remote>/<branch>` como **caché local** del estado remoto en el último `fetch`.
- `git fetch` vs `git pull` (y `pull --rebase`).
- `git ls-remote`.
- Tracking / upstream (`git push -u`, `--set-upstream-to`, `git branch -vv`).
- "Your branch is ahead/behind/diverged by N commits".
- `git push` normal vs force; **protección contra push non-fast-forward**.
- Qué es un **bare repo** (`git init --bare`) y por qué un server lo necesita.
- Refspecs básicas (`refs/heads/*:refs/remotes/origin/*`).

Lo que **no** cubre (va después):
- GitHub, SSH keys, PATs, `gh` CLI → `gh-05`.
- Rebase interactivo → `gh-06`.
- Pull requests y review → `gh-07`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-fetch-vs-pull/` — demuestra en vivo por qué `fetch` nunca modifica tu rama y `pull` sí.
  - `02-two-clones-same-repo/` — dos clones contra un mismo bare remote (simulación de dos usuarios).
- **`activities/`**:
  - `01-local-bare-remote/` — **guided-lab**: crear un bare remote local, un clone, pushear y fetchear end-to-end.
  - `02-collab-simulation-two-clones/` — **independent**: simular colaboración entre Alice y Bob contra un mismo bare remote.
- **`resources/links.md`** — docs oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué Git es **distribuido** (cada clon es un repo completo). Describir `origin/main` como *caché local* del estado remoto en el último fetch, no como "la rama remota en vivo". Diferenciar `fetch` (red + actualiza cachés) de `pull` (fetch + merge/rebase). Explicar por qué el servidor rechaza un push non-fast-forward por defecto. |
| Operativa | Crear un bare remote, clonarlo, pushear con `-u`, fetchear, resolver "ahead/behind", usar `pull --rebase` como default razonable, interpretar `git branch -vv`. |
| Arquitectónica | Elegir entre `pull` default (merge) vs `pull --rebase` para un equipo; justificar el uso de SSH sobre HTTPS en entornos profesionales; diseñar la convención de `origin` / `upstream` (fork workflow). |

## Entregable

- Un **bare remote local** funcionando en `/tmp/gh-04-bare/origin.git/` y uno o dos clones trabajando contra él (actividad 02). Sin GitHub.

## Criterios de evaluación

- Capacidad de recrear el setup bare+clone desde cero sin ayuda.
- Explicar, sin consultar, **por qué** `git fetch` es seguro y `git pull` puede sorprender.
- Interpretar correctamente los 3 estados posibles tras `git fetch`: **up-to-date**, **ahead**, **behind**, **diverged**.
- Responder las 8 preguntas de evaluación de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` secciones 1–6.
2. Reproduce `examples/01-fetch-vs-pull/`.
3. Haz `activities/01-local-bare-remote/` (guided).
4. Lee `theory/lesson.md` secciones 7–10.
5. Reproduce `examples/02-two-clones-same-repo/`.
6. Haz `activities/02-collab-simulation-two-clones/` (independent — la que valida).
7. Responde las 8 preguntas de evaluación sin consultar.

## Siguiente

→ `gh-05-github-first-contact`.
