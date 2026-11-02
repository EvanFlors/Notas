#!/usr/bin/env bash
# Caso 2: en `cmd1 && cmd2`, si `cmd1` falla, `set -e` NO aborta;
# simplemente no ejecuta `cmd2` y sigue con la línea siguiente.
set -euo pipefail
IFS=$'\n\t'

false && echo "no entro aquí"

# `-e` no abortó: `false` era el operando izquierdo de `&&`.
echo "continué después de un comando que falló"
exit 0
