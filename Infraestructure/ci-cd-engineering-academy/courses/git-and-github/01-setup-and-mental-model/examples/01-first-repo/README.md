# Ejemplo 01 — First repo: ver objetos aparecer

## Concepto que demuestra

El ciclo `init → add → commit` y qué objetos aparecen en `.git/objects/` en cada paso.

## Contexto

Primer repositorio Git. Objetivo: *ver* qué pasa, no "memorizar comandos".

## Objetivo

Al terminar, podrás responder:
- ¿Qué objeto crea `git add`?
- ¿Qué objetos crea `git commit`?
- ¿Qué contiene cada uno?

## Prerrequisitos

- Git instalado (`git --version` ≥ 2.30 recomendado).
- Bash o shell equivalente.
- Directorio escribible (usaremos `/tmp/`).

## Ejecución

Copia-pega este bloque en una terminal. **Lee la salida de cada comando antes de ejecutar el siguiente.**

```bash
# Preparar
rm -rf /tmp/git-demo && mkdir /tmp/git-demo && cd /tmp/git-demo

# 1. Crear repo
git init
ls -la .git/
# Mira: HEAD, config, hooks/, objects/, refs/

cat .git/HEAD
# "ref: refs/heads/main" (o 'master' si usas Git muy viejo)

ls .git/objects/
# info/  pack/     ← vacío todavía

# 2. Crear un archivo
echo "Hola, Git" > saludo.txt
git status

# 3. git add → crea un BLOB
git add saludo.txt
find .git/objects -type f
# aparece .git/objects/XX/YYYYYY...  (XX = primeros 2 hex del hash)

# Ver qué es
HASH_BLOB=$(git hash-object saludo.txt)
echo "Blob hash: $HASH_BLOB"
git cat-file -t $HASH_BLOB     # tipo: blob
git cat-file -p $HASH_BLOB     # contenido

# 4. git commit → crea un TREE y un COMMIT (2 objetos más)
#    Configuramos identidad temporal solo para este demo.
git -c user.name=Demo -c user.email=demo@example.com commit -m "primer commit"

find .git/objects -type f | sort
# Ahora deberías ver 3 archivos: blob + tree + commit

# 5. Explorar el commit
HASH_COMMIT=$(git rev-parse HEAD)
echo "Commit hash: $HASH_COMMIT"

git cat-file -p $HASH_COMMIT
# tree <HASH_TREE>
# author Demo <demo@example.com> ...
# committer ...
# <blank>
# primer commit

# 6. Explorar el tree
HASH_TREE=$(git rev-parse HEAD^{tree})
git cat-file -p $HASH_TREE
# 100644 blob <HASH_BLOB>    saludo.txt

# 7. ¡La rama "main" es un archivo!
cat .git/refs/heads/main
# <HASH_COMMIT>

# 8. git log usa esta estructura
git log --oneline
```

## Resultado esperado

- 3 objetos en `.git/objects/`.
- `git cat-file -p HEAD` muestra el commit con su hash de tree.
- `git cat-file -p HEAD^{tree}` muestra el tree con `saludo.txt → blob`.
- `cat .git/refs/heads/main` imprime el hash del commit.

## Interpretación

- `git add` serializa el *contenido* del archivo como blob y actualiza el index. Nombre y modo viven en el index, no en el blob.
- `git commit` toma el index, construye el tree correspondiente (si no existía), y crea el commit que apunta al tree.
- La rama `main` es una ref — un archivo con un hash dentro. Mover la rama es cambiar el valor de ese archivo.

## Errores frecuentes

- **"Please tell me who you are"**: no configuraste identidad global. Para este demo usamos `-c user.name=... -c user.email=...` inline.
- **"hint: Using 'master' as the name..."**: tu `init.defaultBranch` no está en `main`. Corregir con `git config --global init.defaultBranch main`.
- **No ves archivos en `.git/objects/`**: olvidaste `git add`.

## Relación con escenarios reales

- Cuando un pipeline CI falla con "fatal: not a git repository", sabes que buscar `.git/` ausente.
- Cuando debugueas un bug de identidad en commits de un bot CI, miras `git log --format='%an <%ae>'`.
- Cuando alguien dice "perdí mi branch", sabes que los commits probablemente siguen en `objects/`; se recuperan por `reflog`.

## Limpieza

```bash
rm -rf /tmp/git-demo
```
