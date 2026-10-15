# Ejemplo 01 — Construir un commit a mano con plumbing

## Concepto que demuestra

Que un commit es, por debajo, **el resultado de encadenar cuatro llamadas** a comandos plumbing: `hash-object` (blob) → `mktree` (tree) → `commit-tree` (commit) → `update-ref` (ref).

Al terminar deberías poder decir "sé exactamente qué hace `git commit`" sin manos sudorosas.

## Contexto

En gh-01 vimos los **tres áreas** y en gh-02 el **index**. Aquí entramos a lo que hay debajo del index: el **object store**. Las operaciones diarias (`add`, `commit`) son azúcar encima de estos comandos.

## Objetivo

Al terminar:
- Creas un blob desde contenido en memoria.
- Construyes un tree que lo referencia.
- Construyes un commit sin padres (initial) y uno con padre (segundo).
- Mueves `refs/heads/main` manualmente.
- Inspeccionas cada objeto con `cat-file -p`.

## Prerrequisitos

- Git ≥ 2.30.
- Haber leído secciones 1–5 de `theory/lesson.md`.

## Ejecución

Opción A: ejecuta el script `files/run-demo.sh`.
Opción B (recomendada para aprender): copia-pega cada paso.

```bash
# ---------------------------------------------------------------
# 0) Setup
# ---------------------------------------------------------------
rm -rf /tmp/plumb-demo && mkdir /tmp/plumb-demo && cd /tmp/plumb-demo
git init -q -b main
git config user.name  "Plumber"
git config user.email "plumber@example.com"

# ---------------------------------------------------------------
# 1) Primer commit, 100% plumbing
# ---------------------------------------------------------------

# 1.1) Blob
BLOB1=$(echo "hello world" | git hash-object --stdin -w)
echo "blob1 = $BLOB1"

# Verifica que el blob existe en el object store
ls .git/objects/${BLOB1:0:2}/
# → <resto del hash>

git cat-file -t "$BLOB1"    # blob
git cat-file -s "$BLOB1"    # 12 (= len("hello world\n"))
git cat-file -p "$BLOB1"    # hello world

# 1.2) Tree que contiene el blob como hello.txt
TREE1=$(printf '%s %s %s\t%s\n' 100644 blob "$BLOB1" hello.txt | git mktree)
echo "tree1 = $TREE1"

git cat-file -t "$TREE1"    # tree
git cat-file -p "$TREE1"
# 100644 blob <BLOB1>  hello.txt

# 1.3) Commit sin padres (initial)
COMMIT1=$(echo "initial commit (plumbing)" | git commit-tree "$TREE1")
echo "commit1 = $COMMIT1"

git cat-file -p "$COMMIT1"
# tree <TREE1>
# author Plumber <plumber@example.com> ...
# committer Plumber <plumber@example.com> ...
#
# initial commit (plumbing)

# 1.4) Mover main
git update-ref refs/heads/main "$COMMIT1"
git log --oneline
# <COMMIT1> initial commit (plumbing)
```

En este punto `git log` ya reconoce la historia. Pero **el working tree sigue vacío** (`ls` no muestra `hello.txt`). Para materializarlo:

```bash
git reset --hard HEAD    # sincroniza index + working tree desde el tree de HEAD
ls                    # hello.txt
cat hello.txt         # hello world
```

```bash
# ---------------------------------------------------------------
# 2) Segundo commit encadenado al anterior
# ---------------------------------------------------------------

# 2.1) Nuevo blob (otro contenido)
BLOB2=$(printf 'line1\nline2\n' | git hash-object --stdin -w)
echo "blob2 = $BLOB2"

# 2.2) Nuevo tree: hello.txt (sin cambio) + notes.txt (nuevo)
TREE2=$(printf '%s %s %s\t%s\n%s %s %s\t%s\n' \
          100644 blob "$BLOB1" hello.txt \
          100644 blob "$BLOB2" notes.txt | git mktree)
echo "tree2 = $TREE2"

git cat-file -p "$TREE2"
# 100644 blob <BLOB1>  hello.txt
# 100644 blob <BLOB2>  notes.txt

# 2.3) Commit con padre = COMMIT1
COMMIT2=$(echo "add notes.txt" | git commit-tree "$TREE2" -p "$COMMIT1")
echo "commit2 = $COMMIT2"

git cat-file -p "$COMMIT2"
# tree <TREE2>
# parent <COMMIT1>
# ...

# 2.4) Mover main
git update-ref refs/heads/main "$COMMIT2"
git log --oneline
# <COMMIT2> add notes.txt
# <COMMIT1> initial commit (plumbing)

# Materializar
git reset --hard HEAD >/dev/null
ls
# hello.txt   notes.txt
```

## Resultado esperado

- `git log --oneline` muestra dos commits encadenados.
- `git cat-file -p HEAD` muestra `tree <TREE2>` y `parent <COMMIT1>`.
- `git ls-tree HEAD` lista los dos blobs.
- `.git/objects/` contiene **cinco objetos**: 2 blobs, 2 trees, 2 commits (bueno, en realidad: BLOB1 compartido entre TREE1 y TREE2 → 2 blobs únicos, 2 trees únicos, 2 commits únicos = 6; o 5 si cuentas BLOB1 una sola vez. Lo importante: content addressing deduplica).

## Interpretación

- **Un commit no "contiene" los archivos**: contiene un **hash a un tree**. El tree es el que lista archivos.
- **`parent` es un hash a otro commit**. Cambiar el parent cambia el hash del commit → por eso `rebase` genera commits nuevos.
- **El working tree es efímero**: puedes borrar `hello.txt` del disco y el commit sigue intacto; `git checkout` lo re-materializa.
- **El index no participó**. Lo hemos *puenteado*. En uso diario, `git add` y `git write-tree` son más cómodos — pero conceptualmente son opcionales.

## Errores frecuentes

- **Olvidar `-w` en `hash-object`**: calcula el hash pero **no escribe** el blob al object store. Luego `git mktree` falla porque el blob no existe. Siempre `-w` cuando quieras construir algo real.
- **Pasar `mktree` entradas desordenadas**: Git ordena internamente, pero si duplicas nombres falla.
- **No usar TAB entre hash y nombre en el input de `mktree`**: el formato es `<mode> SP <type> SP <hash> TAB <name>\n`. Espacio donde iba TAB → error.
- **Olvidar `git checkout -- .` tras `update-ref`**: `git status` dirá que te faltan todos los archivos ("deleted"), lo cual confunde. No hay bug, solo falta materializar.

## Relación con escenarios reales

- Hooks del servidor que necesitan **crear commits sintéticos** (p. ej. `squash-and-merge` de GitHub por dentro usa estos plumbing).
- Herramientas tipo `git filter-repo`, `git-fast-import` operan directamente contra el object store sin pasar por index.
- Depurar "¿por qué este rebase cambió el autor?" implica leer `cat-file -p` del commit viejo y del nuevo lado a lado.

## Limpieza

```bash
rm -rf /tmp/plumb-demo
```
