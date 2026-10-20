# Solución — gh-09-01-commit-from-scratch-plumbing

> **No consultes esta solución antes de intentar la actividad.**

Script: [`solve.sh`](./solve.sh). Ejecuta `bash solve.sh /tmp/plumbing-lab`.

## Resumen conceptual

Para cada commit encadenado se repite el mismo patrón:

1. **blob**: `git hash-object --stdin -w` (desde el contenido literal; `-w` lo escribe al object store).
2. **tree**: `git mktree` recibiendo líneas `<mode> SP <type> SP <hash> TAB <name>\n`.
3. **commit**: `git commit-tree <tree> [-p <parent>]` recibiendo el mensaje por stdin.
4. **ref**: `git update-ref refs/heads/main <commit>`.

## Esperados exactos (SHA-1, deterministas por contenido)

Como el contenido de los blobs es constante, sus hashes también:

- `hello\n` → `ce013625030ba8dba906f756967f9e9ca394464a`
- `#!/bin/sh\necho hello\n` → `21ba682558a42264518f1e0ba55e8a5cd9d7db0a`

Los hashes de `tree` y `commit` incluyen metadata (author, timestamp del committer), así que **variarán** entre ejecuciones aun si el contenido lógico es el mismo. Por eso el validador no compara hashes de commit/tree completos: compara **contenido** (blobs y entradas de tree).

## Variante alternativa (vía index)

Si prefieres pasar por el index, los dos primeros pasos cambian:

```bash
# Blob 1 + index
BLOB1=$(printf 'hello\n' | git hash-object --stdin -w)
git update-index --add --cacheinfo 100644,"$BLOB1",hello.txt
TREE1=$(git write-tree)
# ... resto igual
```

El resultado es idéntico: el tree termina siendo el mismo objeto (mismo contenido ⇒ mismo hash).
