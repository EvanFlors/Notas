#!/usr/bin/env bash
# Caso 4: `local x=$(cmd)` traga el exit code de `cmd`.
# El exit code que `set -e` evalúa es el de `local` (siempre 0).
set -euo pipefail
IFS=$'\n\t'

mi_funcion() {
    # `false` falla, pero `local` succeed-ea → `-e` no aborta.
    local resultado=$(false; echo "valor-fantasma")
    echo "mi_funcion continuó; resultado='$resultado'"
}

mi_funcion

echo "continué después de una función con un fallo oculto"
exit 0
