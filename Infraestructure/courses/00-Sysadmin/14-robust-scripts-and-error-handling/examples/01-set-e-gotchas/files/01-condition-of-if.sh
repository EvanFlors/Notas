#!/usr/bin/env bash
# Caso 1: comando en la condición de un `if` NO dispara `set -e`.
# Resultado: el script llega al final e imprime "continué".
set -euo pipefail
IFS=$'\n\t'

if false; then
    echo "no entro aquí"
fi

# `-e` no abortó: `false` estaba en una condición.
echo "continué después de un comando que falló"
exit 0
