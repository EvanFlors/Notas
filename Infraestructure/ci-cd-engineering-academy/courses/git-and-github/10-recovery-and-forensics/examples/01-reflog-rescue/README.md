# Ejemplo 01 — Reflog rescue

## Concepto que demuestra

Cómo recuperar commits "perdidos" tras `git reset --hard` usando `git reflog`, y qué pasa con los objetos a nivel de `.git/objects/`.

## Contexto

Caso real: ejecutas `git reset --hard` sobre la rama equivocada o pasas un hash equivocado. En `git log` ya no está lo que querías. Antes de entrar en pánico: `git reflog`.

## Objetivo

Al terminar:
- Entiendes la diferencia entre `git log` (DAG desde la ref) y `git reflog` (diario local de movimientos).
- Sabes recuperar un commit con `reset --hard <sha>` o `cherry-pick <sha>`.
- Observas que el objeto nunca se borró de `.git/objects/`.

## Prerrequisitos

- Git ≥ 2.30.
- Haber completado `gh-09`.

## Ejecución

Usa el script `files/run-demo.sh` o reproduce manualmente:

```bash
rm -rf /tmp/reflog-demo && mkdir /tmp/reflog-demo && cd /tmp/reflog-demo
git init -q -b main
git config user.name  "Demo" && git config user.email "demo@example.com"

# Historia pequeña: 3 commits
echo "line 1" > notes.md
git add . && git commit -q -m "init: notes"

echo "line 2" >> notes.md
git add . && git commit -q -m "add: line 2"

echo "line 3" >> notes.md
git add . && git commit -q -m "add: line 3 (important work)"

git log --oneline
# <h3> add: line 3 (important work)
# <h2> add: line 2
# <h1> init: notes
```

Ahora el "accidente":

```bash
git reset --hard HEAD~2
git log --oneline
# <h1> init: notes      ← los otros dos "desaparecieron"
cat notes.md
# line 1                ← también en el working tree
```

Diagnóstico:

```bash
git reflog
# <h1> HEAD@{0}: reset: moving to HEAD~2
# <h3> HEAD@{1}: commit: add: line 3 (important work)
# <h2> HEAD@{2}: commit: add: line 2
# <h1> HEAD@{3}: commit (initial): init: notes
```

El commit `add: line 3` sigue vivo: es `HEAD@{1}` (y tiene su hash). Verifica que el objeto está en `.git/objects/`:

```bash
HASH=$(git rev-parse HEAD@{1})
echo "lost hash: $HASH"
git cat-file -p "$HASH"
# tree ...
# parent ...
# ...
# add: line 3 (important work)
```

Rescate — opción A, mover `main` entero al estado perdido:

```bash
git reset --hard HEAD@{1}
git log --oneline
# <h3> add: line 3 (important work)
# <h2> add: line 2
# <h1> init: notes
cat notes.md
# line 1
# line 2
# line 3
```

Rescate — opción B (si solo quieres el commit, no toda la cadena): `git cherry-pick HEAD@{1}`.

## Resultado esperado

- `git log` muestra los 3 commits de nuevo.
- `notes.md` tiene las 3 líneas.
- Entiendes que el objeto estuvo siempre en `.git/objects/`; solo faltaba un puntero (ref) hacia él.

## Interpretación

- **`reset --hard` no toca `.git/objects/`**. Mueve una ref y sobrescribe el working tree.
- **El reflog es un diario append-only por ref local**. Cada movimiento de HEAD/`main` deja huella en `.git/logs/`.
- **`HEAD@{N}` es sintaxis sobre el reflog**, no sobre el DAG. `HEAD~N` sí camina el DAG.

## Observación avanzada: ¿cuándo moriría el objeto?

- Por default, un objeto no reachable por ref viva se mantiene mientras exista una entrada de reflog que lo apunte (hasta `gc.reflogExpireUnreachable`, 30 días).
- Para forzar: `git reflog expire --expire=now --all && git gc --prune=now` — **destruye** cualquier objeto no reachable. Nunca lo hagas en un repo activo "por limpieza".

## Errores frecuentes

- **"No encuentro el reflog" tras un `clone`**: el reflog es local; empieza vacío en cada clon.
- **Confundir `HEAD@{1}` con `HEAD~1`**: `~1` = padre en el DAG; `@{1}` = estado anterior según el diario.
- **Entrar en pánico y hacer `gc`**: la cura es peor que la enfermedad.

## Relación con escenarios reales

- Recovery tras `reset --hard`, `rebase` corrupto, `checkout <otra-rama>` que sobrescribió cambios sin stash.
- Siempre que algo "desaparezca" después de una operación local: `git reflog` es el primer comando.

## Limpieza

```bash
rm -rf /tmp/reflog-demo
```
