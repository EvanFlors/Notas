# gh-03 — Branching and merging basics

## Identificación

- **ID:** `gh-03-branching-and-merging-basics`
- **Curso:** `git-and-github`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** `gh-02-recording-changes`.

## Objetivo

Usar **branches como lo que son**: punteros móviles sobre el DAG de commits. Fusionar con criterio (fast-forward vs 3-way merge), **leer** el grafo con `git log --graph`, y **resolver conflictos** razonando sobre los tres snapshots involucrados (base común + lado nuestro + lado suyo).

Al terminar deberías poder predecir qué pasa con `HEAD` y las refs tras cada operación y explicar un merge commit en términos de árboles.

## Alcance

- `git branch` (listar, crear, borrar, renombrar); naming conventions.
- `git switch` (moderno) y `git checkout` (legacy); `switch --create`, `switch --detach`.
- **Fast-forward** vs **3-way merge** vs `--no-ff` (y por qué cada estrategia produce una historia distinta).
- **Resolución de conflictos**: editor + `git mergetool`, marcadores (`<<<<<<<`, `=======`, `>>>>>>>`), `git status` como mapa, `--abort` / `--continue`.
- Lectura del grafo: `git log --graph --oneline --all --decorate`.
- `HEAD` como *ref-a-ref*; **detached HEAD** (qué es, cómo salir, cuándo es útil).
- Qué registra exactamente Git al hacer un merge: un commit con **dos padres** apuntando a un tree resultante.

Lo que **no** cubre (va después):
- `git rebase` y rebase interactivo → `gh-06`.
- Remotos, `push`/`pull`, tracking branches → `gh-04`.
- Pull requests y estrategias de merge en GitHub (squash / rebase and merge) → `gh-07`.
- `git reflog`, `git bisect`, recuperación avanzada → `gh-10`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-fast-forward-vs-merge/` — misma secuencia de commits ejecutada con FF, `--no-ff`, y 3-way; comparación del `--graph`.
  - `02-conflict-walkthrough/` — anatomía de un conflicto: cómo lo marca Git, cómo lo lees, cómo lo resuelves.
- **`activities/`**:
  - `01-branch-and-merge/` — guided-lab: ciclo completo (branch → FF merge → 3-way merge → resolver un conflicto simple).
  - `02-resolve-nontrivial-conflict/` — guided-lab: tres ramas, dos merges, conflictos en varios archivos.
- **`resources/links.md`** — docs oficiales verificadas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué es una rama (una ref mutable que apunta a un commit) y qué es `HEAD` (una ref que apunta a otra ref, o directamente a un commit en *detached HEAD*). Diferenciar fast-forward de 3-way merge en términos del DAG. Describir qué contiene un merge commit (tree + ≥ 2 padres). |
| Operativa | Crear/borrar/renombrar ramas; moverte con `switch`; mergear con y sin `--no-ff`; leer `git log --graph`; resolver un conflicto desde el editor sin pánico; abortar un merge mal ejecutado. |
| Arquitectónica | Elegir cuándo forzar `--no-ff` (preservar el contexto de la feature) vs permitir FF (historia lineal). Diseñar una convención de naming de ramas efímeras coherente con el workflow del equipo. |

## Criterios de evaluación

- Produces un DAG con **3 o más ramas** y lo imprimes con `git log --graph --oneline --all --decorate` como entregable.
- Predices sin consultar qué pasa con `HEAD`, la rama actual y la rama destino tras `switch`, `merge --ff-only`, `merge --no-ff`, `merge` (3-way), `branch -d`, `branch -D`.
- Resuelves un conflicto no trivial y explicas por qué el resultado es correcto en términos de las tres versiones involucradas (**base**, **ours**, **theirs**).
- Las dos actividades de este módulo pasan sus `tests/validate.sh`.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-fast-forward-vs-merge/` paso a paso en `/tmp/`.
3. Reproduce `examples/02-conflict-walkthrough/` y detente a leer el output de `git status` tras el conflicto.
4. Haz `activities/01-branch-and-merge/` (guided).
5. Haz `activities/02-resolve-nontrivial-conflict/` (guided más denso).
6. Responde las preguntas de evaluación de `theory/lesson.md` sin consultar.

## Siguiente

→ `gh-04-remotes-and-collaboration-basics` (ya con ramas sólidas, aprendemos el modelo distribuido).
→ `gh-06-rebase-vs-merge-and-interactive` (alternativa a los merges 3-way: reescribir vs mergear).
