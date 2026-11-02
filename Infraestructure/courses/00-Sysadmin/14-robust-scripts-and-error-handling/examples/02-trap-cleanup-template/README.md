# Ejemplo 02 — Plantilla de `trap` + cleanup

## Concepto que demuestra

Un script "esqueleto" que combina `set -euo pipefail`, `trap EXIT` para cleanup incondicional, `trap ERR` para reporte con línea y comando, y manejo explícito de `INT`/`TERM` con exit codes convencionales (`130`/`143`).

## Contexto

Casi todos los scripts no triviales acaban necesitando este cascarón. Copiarlo, adaptarlo y arrancar con él es más seguro que reinventarlo.

## Objetivo

Al terminar podrás usar `files/template.sh` como base para tus propios jobs y entender cada línea de boilerplate.

## Prerrequisitos

- `bash` ≥ 4.0.
- `mktemp` disponible (coreutils).

## Ejecución

Caso feliz:

```bash
bash files/template.sh
echo "exit: $?"
```

Deberías ver bitácora `[INFO]` y `[INFO] done` en stderr y exit 0. El `tmpdir` creado por `mktemp -d` se borra incluso con éxito.

Simular fallo:

```bash
FAIL=1 bash files/template.sh
echo "exit: $?"
```

Deberías ver `[ERROR] línea …: "false" (exit 1)` y exit distinto de 0. Comprueba que **no quedó** ningún `/tmp/tmp.XXXXXX` del script.

Simular `Ctrl-C` (en una terminal interactiva):

```bash
SLEEP=5 bash files/template.sh
# en otra terminal, o Ctrl-C aquí a mitad: pulsa Ctrl-C en el primer segundo
```

Deberías ver `[WARN] SIGINT` y exit `130`. El tmpdir se borra igual.

## Resultado esperado

- Caso feliz: exit 0, tmpdir inexistente al final.
- Caso fallo: exit no cero, mensaje de ERROR con línea y comando, tmpdir inexistente.
- Caso `INT`: exit 130, mensaje WARN, tmpdir inexistente.

## Interpretación

- El `trap cleanup EXIT` dispara en **todos** los caminos de salida (éxito, fallo, señal, `exit` explícito).
- El `trap on_err ERR` da contexto sin cambiar el flujo: `-e` sigue siendo quien aborta; `ERR` solo loguea.
- Los exit codes `130` y `143` siguen la convención `128 + señal` (ver `signal(7)`).

## Errores frecuentes

- Olvidar propagar el exit code dentro del handler: `cleanup() { … exit "$rc"; }` restaura el código real.
- Registrar `trap` **después** de operaciones peligrosas. El `trap` cubre a partir de que se registra; ponerlo arriba.

## Relación con escenarios reales

- Backup script: tmpdir con tarball parcial; si muere, no debe dejar basura.
- Deploy script: lock + tmpdir para checkout + señales de un operador que pulsa `Ctrl-C` al ver un error.

## Limpieza

Nada que limpiar fuera del propio script (es idempotente y auto-contenido).
