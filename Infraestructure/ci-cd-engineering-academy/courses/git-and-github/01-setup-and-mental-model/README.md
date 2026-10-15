# gh-01 — Setup y modelo mental de Git

## Identificación

- **ID:** `gh-01-setup-and-mental-model`
- **Curso:** `git-and-github`
- **Nivel:** fundamentos
- **Duración estimada:** 3–4 h
- **Prerrequisitos:** línea de comandos básica (navegación, edición de texto). Un editor instalado.

## Objetivo

Instalar Git, configurar identidad y editor, y **construir el modelo mental correcto** (DVCS, snapshots inmutables, DAG, tres áreas, objetos). Al terminar, deberías poder abrir `.git/` y explicar qué es cada cosa.

## Alcance

Este módulo cubre:

- Qué resuelve un DVCS y por qué Git ganó.
- Hashing de contenido, snapshots vs deltas, grafo acíclico dirigido (DAG).
- Tres áreas lógicas: `working tree` → `index/staging` → `repository`.
- Objetos: `blob`, `tree`, `commit`, `tag`. Referencias (`HEAD`, `refs/heads/*`).
- Instalación por SO.
- Configuración (`git config` global): identidad, editor, defaults modernos, credential helpers.
- Primeros comandos de operación: `init`, `status`, `add`, `commit`, `log`.
- Qué pasa en `.git/` al ejecutar cada operación.

Lo que **no** cubre (se verá después):
- Branching, merge, rebase → `gh-03`.
- Remotes y colaboración → `gh-04`.
- GitHub como plataforma → `gh-05`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos:
  - `01-first-repo/` — crear repo mínimo y observar objetos generados.
  - `02-what-is-in-dot-git/` — anatomía anotada de `.git/`.
- **`activities/`** — tres actividades:
  - `01-config-personal/` — configuración global sana (guided).
  - `02-first-commits/` — ciclo `init → add → commit` observando el estado (guided).
  - `03-explore-dot-git/` — mapear `.git/` y explicar cada entrada (independent).
- **`resources/links.md`** — referencias verificables.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar sin consultar docs qué contiene un commit (en términos de objetos). Diferenciar `working tree` / `index` / `repository`. Decir qué pasa en `.git/objects/` al hacer `git add` vs `git commit`. |
| Operativa | Inicializar un repo, configurar identidad y defaults, hacer commits atómicos, leer `.git/HEAD` y `.git/refs/`, usar `git log` con filtros básicos. |
| Arquitectónica | Justificar DVCS frente a VCS centralizado para un escenario dado. Elegir defaults de config con criterio (no por copia-pega). |

## Criterios de evaluación

- Repo creado y configurado.
- Al menos 5 commits atómicos con mensajes significativos.
- Capacidad de leer `.git/HEAD`, `.git/refs/heads/main`, y describir qué apunta a qué.
- Capacidad de ejecutar `git cat-file -p <hash>` sobre al menos un `blob`, un `tree` y un `commit` propios.
- Respuesta argumentada a las preguntas de evaluación al final de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada).
2. Reproduce `examples/01-first-repo/` observando cada comando.
3. Haz la actividad `activities/01-config-personal/` para dejar tu Git sano.
4. Haz la actividad `activities/02-first-commits/`.
5. Lee `examples/02-what-is-in-dot-git/` como material de referencia.
6. Haz la actividad `activities/03-explore-dot-git/` (es la que valida comprensión real).
7. Responde las preguntas de evaluación de la lección sin consultar.

## Siguiente

→ `gh-02-recording-changes`: ciclo diario de trabajo con staging selectivo, deshacer cambios, `.gitignore` y `.gitattributes`.
