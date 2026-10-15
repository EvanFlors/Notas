# gh-10 — Recovery and forensics

## Identificación

- **ID:** `gh-10-recovery-and-forensics`
- **Curso:** `git-and-github`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `gh-09-git-internals`.

## Objetivo

Operar Git como **red de seguridad** y como **laboratorio forense**: recuperar trabajo "perdido" (reset accidental, rama borrada, stash desaparecido) y localizar con precisión el commit que introdujo un bug usando `bisect`, `blame`, pickaxe (`log -S/-G`) y `log --follow`. Al terminar, dado un repo "roto", deberías poder restaurar la historia sin consultar guías.

## Alcance

- `git reflog` — diario de HEAD y refs locales; reflogs **por rama**; expiración (`gc.reflogExpire`, `gc.reflogExpireUnreachable`).
- `git fsck --lost-found` — rescatar objetos huérfanos cuando el reflog ya expiró o se borró.
- `git bisect` — bisección manual (`good`/`bad`/`skip`) y automatizada (`bisect run <test.sh>`); interpretación del resultado.
- `git blame` — autoría línea por línea; `-L` (rangos), `-C`/`-M` (seguir copias y movimientos).
- `git log -S<string>` y `git log -G<regex>` — **pickaxe**: encontrar el commit que introdujo o eliminó un token.
- `git log --follow <file>` — seguir un archivo a través de renombres.
- `git worktree` — múltiples working trees sobre el mismo `.git/`; útil para investigar sin perturbar el actual.
- `git stash` — qué es realmente (dos commits en `refs/stash`), por qué no abusarlo.
- `git reset --soft/--mixed/--hard` — qué queda huérfano tras cada modo y cuándo lo recoge `gc`.

Lo que **no** cubre (va en otros módulos):
- Objetos y packfiles → `gh-09`.
- Hooks, submódulos, LFS → `gh-11`.
- Firma y verificación de commits → `gh-13`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-reflog-rescue/` — walkthrough: perder un commit con `reset --hard`, encontrarlo en el reflog y re-aplicarlo.
  - `02-bisect-with-script/` — walkthrough: `git bisect run <test.sh>` sobre un repo con una regresión plantada.
- **`activities/`**:
  - `01-rescue-after-reset-hard/` — **independent**: tres rescates encadenados (reflog, rama borrada, stash eliminado del reflog recuperado vía `fsck --lost-found`).
  - `02-bisect-regression/` — **guided-lab**: ~20 commits, uno introduce un bug detectado por un test; localízalo con `bisect run`.
- **`resources/links.md`** — docs oficiales y lecturas complementarias.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `reset --hard` no borra objetos inmediatamente. Diferenciar `reflog` vs `log`. Describir qué garantiza `bisect` (log₂ pasos) y qué asume (monotonicidad del test). Decir qué queda **irrecuperable** y cuándo. |
| Operativa | Recuperar un commit perdido vía reflog **y** vía `fsck --lost-found` cuando el reflog ya no sirve. Automatizar un `bisect` con `--run` y un script con códigos de salida convenidos (0 good / 1 bad / 125 skip). Usar `blame -L` y pickaxe para auditar la introducción de una línea. |
| Arquitectónica | Decidir cuándo aumentar `gc.reflogExpire` para equipos. Diseñar scripts de test rápidos y determinísticos para que `bisect run` sea útil. Elegir entre `stash` y `worktree` según el caso. |

## Criterios de evaluación

- Resolver las dos actividades sin consultar `solution/`.
- Explicar, por escrito, qué objetos quedan huérfanos tras `git reset --hard HEAD~3` y cuándo exactamente los recoge `git gc`.
- Dado un repo con un bug en un commit entre 100 commits, encontrarlo con `bisect run` en < 10 minutos.
- Responder las 6–8 preguntas de evaluación de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md`.
2. Reproduce `examples/01-reflog-rescue/`.
3. Haz `activities/01-rescue-after-reset-hard/` (independent — recuperación avanzada).
4. Reproduce `examples/02-bisect-with-script/`.
5. Haz `activities/02-bisect-regression/` (guided-lab con bisect automatizado).
6. Responde las preguntas de evaluación sin consultar.

## Siguiente

→ `gh-11-hooks-submodules-subtrees-lfs`.
