# Actividad 02 — Renombrado masivo idempotente

- **ID:** `sys-16-02-bulk-rename`
- **Tipo:** independent
- **Duración:** 60 min
- **Nivel:** intermedio

## Contexto

Tienes un directorio de fotos exportadas con nombres heterogéneos (`DSCN0123.JPG`, `20240815_142301.jpg`, `IMG-20240815-WA0001.jpeg`, …). Quieres **unificarlas** al esquema:

```
IMG_YYYYMMDD_HHMMSS.jpg
```

donde la fecha/hora se toma del `mtime` del archivo (para evitar depender de EXIF, que no se cubre aquí).

Debe ser:

- **Idempotente**: si una foto ya tiene el nombre correcto, no se toca.
- **Determinista**: si dos fotos colisionan en segundo, se desempatan con un sufijo `_01`, `_02`, …
- **Reversible por inspección**: imprime cada `renombrado: A -> B`.
- **Con `--dry-run`**: por defecto no toca el filesystem; sólo imprime lo que haría. Para ejecutar de verdad, se pasa `--apply`.

## Setup

```bash
bash starter/setup.sh /tmp/sys16-photos
ls -1 /tmp/sys16-photos
```

El starter crea `/tmp/sys16-photos/` con ~8 fotos de nombres variados y `mtime` conocidos.

## Tu tarea

Crea `rename.sh` que:

- Reciba como primer argumento el directorio con las fotos.
- Acepte las flags `--dry-run` (por defecto) y `--apply`.
- Para cada archivo `*.jpg|*.jpeg|*.JPG|*.JPEG` del directorio (no recursivo):
  - Calcule el nombre destino `IMG_YYYYMMDD_HHMMSS.jpg` (siempre `.jpg` minúsculas) a partir del `mtime`.
  - Si el nombre actual ya coincide con el destino, no hace nada.
  - Si el destino ya existe y es otro archivo, añade sufijo `_01`, `_02`, … hasta encontrar hueco libre.
  - Si `--apply`, mueve el archivo; si no, sólo imprime.
- Use `#!/usr/bin/env bash`, `set -euo pipefail`, `IFS=$'\n\t'`.
- Pase `shellcheck` sin warnings.

Pista sobre el `mtime`:

```bash
# Linux:
stat -c '%Y' -- file     # epoch seconds
# BSD/macOS:
stat -f '%m' -- file
# Portable para formatear:
date -r "$epoch" '+%Y%m%d_%H%M%S'   # BSD/macOS; en GNU: date -d "@$epoch" '+%Y%m%d_%H%M%S'
```

Elige una ruta portable o detecta el sistema.

## Validación

```bash
# Reset y preparación
bash starter/setup.sh /tmp/sys16-photos

# Dry-run (default): no debe mover nada
bash rename.sh /tmp/sys16-photos

# Apply real
bash rename.sh /tmp/sys16-photos --apply

# Segunda ejecución apply: no debe mover ningún archivo (idempotencia)
bash rename.sh /tmp/sys16-photos --apply

# Validador
bash tests/validate.sh /tmp/sys16-photos
```

El validador verifica:

- Después de `--apply`, **todos** los archivos siguen el patrón `IMG_YYYYMMDD_HHMMSS(_NN)?.jpg`.
- No se ha perdido ninguna foto (conteo pre/post coincide).
- La ejecución en `--dry-run` **no** modifica el filesystem.
- La segunda ejecución `--apply` es un no-op (idempotencia): ningún `mv` emitido.

## Criterios de evaluación

- Pasa `tests/validate.sh` sin errores.
- `shellcheck rename.sh` sin warnings.
- `--dry-run` es el default (ejecutarlo sin flags es seguro).
- Idempotente.

## Solución de referencia

En `solution/rename.sh`. Léela sólo después de intentarlo.
