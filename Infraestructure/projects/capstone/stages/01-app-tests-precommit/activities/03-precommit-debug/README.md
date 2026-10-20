# Actividad 03 — Debug de pre-commit

El `starter/` trae tres archivos rotos a propósito. Tu trabajo es dejarlos
limpios tal que `pre-commit run --all-files` (si lo ejecutaras) pase, y marcar
la actividad en un archivo `DONE`.

## Archivos rotos del starter

1. `broken-config.yaml` → tiene tabulaciones y una llave mal indentada; `yamllint` falla.
2. `bad_code.py` → tiene import sin usar y función sin anotación de retorno; `ruff` y `mypy` fallan.
3. `trailing.txt` → tiene espacios al final de línea; `trailing-whitespace` falla.

## Entregables (bajo `/tmp/cap-01-03/`)

Copia el starter ahí, repáralo y crea `/tmp/cap-01-03/DONE` con la línea
`precommit-ok`.

## Validar

```bash
bash tests/validate.sh /tmp/cap-01-03
```

El validator **no** ejecuta `pre-commit` (no asumimos red). Verifica
heurísticamente que los tres archivos ya están limpios.
