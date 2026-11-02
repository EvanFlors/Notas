#!/usr/bin/env bash
# Caso 5: $(...) dentro de un string (p. ej. argumento de `echo`) traga el exit code.
# El comando "exterior" (echo) succeed-ea → `-e` no ve el fallo.
set -euo pipefail
IFS=$'\n\t'

echo "resultado: $(false; echo "valor-fantasma")"

echo "continué: el fallo dentro de \$(...) se tragó"
exit 0
