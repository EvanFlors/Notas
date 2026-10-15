# gh-09 — Git internals

## Identificación

- **ID:** `gh-09-git-internals`
- **Curso:** `git-and-github`
- **Nivel:** avanzado
- **Duración estimada:** 5–6 h
- **Prerrequisitos:** `gh-02-recording-changes`, `gh-06-rebase-vs-merge-and-interactive`.

## Objetivo

Comprender Git **desde los objetos hasta los packfiles** para poder depurar cualquier estado. Al terminar, puedes construir un commit sin usar `git commit`, inspeccionar y reparar repos corruptos, y explicar en términos de objetos qué pasa con `commit --amend`, `rebase` y `cherry-pick`.

## Alcance

- Base de datos de objetos (`blob` / `tree` / `commit` / `tag`).
- Content addressing, SHA-1 con `sha1dc`, SHA-256 experimental.
- Plumbing esencial: `hash-object`, `write-tree` / `mktree`, `commit-tree`, `update-ref`, `cat-file`, `ls-tree`, `rev-parse`.
- Refs: directas, symbolic (`HEAD`), `packed-refs`.
- Packfiles (`.pack` + `.idx`), `verify-pack`, delta compression.
- `git fsck`, `git gc`, `git maintenance`, `git prune`.
- Alternates (`.git/objects/info/alternates`) y su uso para recuperación.
- Explicación operacional de `--amend`, `rebase`, `cherry-pick` en términos de objetos.

Lo que **no** cubre (va después):
- Reflog + `bisect` como forenses → `gh-10`.
- Hooks, submódulos, LFS, sparse / partial clone → `gh-11`.
- Firma de commits, SBOM, supply chain → `gh-13`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-build-commit-by-hand/` — recorrido del plumbing completo (blob → tree → commit → ref).
  - `02-inspect-packfile/` — walkthrough de un `.pack` + `.idx` con `verify-pack`.
- **`activities/`**:
  - `01-commit-from-scratch-plumbing/` — guided-lab: construye dos commits encadenados usando solo plumbing.
  - `02-fsck-a-broken-repo/` — **independent**: repo corrupto, debes diagnosticar y recuperar.
- **`resources/links.md`** — docs oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Describir los 4 tipos de objeto y cómo se referencian. Explicar por qué `commit --amend` crea un commit nuevo, por qué `rebase` cambia hashes, qué garantiza la integridad en SHA-1. Distinguir refs directas, symbolic y packed. |
| Operativa | Construir un commit con solo plumbing. Inspeccionar objetos con `cat-file -p` y refs con `rev-parse`. Diagnosticar un repo roto con `fsck` y recuperarlo usando reflog, alternates o un clone de referencia. Leer un packfile con `verify-pack`. |
| Arquitectónica | Decidir cuándo activar `git maintenance`, cuándo usar alternates, cuándo justificar la migración a SHA-256 en un proyecto nuevo. Diseñar backups del repo (objects + refs + packed-refs + HEAD). |

## Criterios de evaluación

- Construye dos commits encadenados sin invocar `git commit` ni `git add` (actividad 01).
- Diagnostica y recupera un repo con un objeto missing usando alternates (actividad 02).
- Responde las 8 preguntas de evaluación de `theory/lesson.md` sin consultar.
- Produce notas con dibujos del DAG y resultados de `cat-file -p` para cada tipo de objeto.

## Secuencia recomendada

1. Lee `theory/lesson.md` secciones 1–5.
2. Reproduce `examples/01-build-commit-by-hand/`.
3. Haz `activities/01-commit-from-scratch-plumbing/` (guided).
4. Lee `theory/lesson.md` secciones 6–8.
5. Reproduce `examples/02-inspect-packfile/`.
6. Haz `activities/02-fsck-a-broken-repo/` (independent — la que valida que "sabes depurar").
7. Lee secciones 9–10 (errores + buenas prácticas) y responde las preguntas de evaluación.

## Siguiente

→ `gh-10-recovery-and-forensics` (reflog, bisect, blame, pickaxe, worktree, stash).
