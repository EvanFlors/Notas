# Starter — precommit-debug

Copia los 3 archivos rotos a `/tmp/cap-01-03/` y arréglalos uno a uno:

```bash
mkdir -p /tmp/cap-01-03
cp broken-config.yaml bad_code.py trailing.txt /tmp/cap-01-03/
```

Pistas:

- `broken-config.yaml`: cambia tabulaciones por 2 espacios y limpia espacios al final.
- `bad_code.py`: borra el import no usado y añade anotaciones de tipo (`a: int, b: int) -> int`).
- `trailing.txt`: elimina los espacios al final de cada línea.

Cuando los tres estén limpios:

```bash
echo precommit-ok > /tmp/cap-01-03/DONE
```
