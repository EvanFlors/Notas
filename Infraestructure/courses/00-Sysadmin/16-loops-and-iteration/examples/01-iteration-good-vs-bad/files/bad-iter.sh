#!/usr/bin/env bash
# ANTIPATRÓN DIDÁCTICO — no copiar.
# Itera parseando `ls`: pierde nombres con espacios y expande globs.
#
# shellcheck disable=SC2045  # el propósito del script es demostrar este error
# shellcheck disable=SC2086  # idem

set -eo pipefail
# Nota: no ponemos IFS=$'\n\t' porque este script muestra qué pasa con IFS por defecto.

DIR="${1:-.}"
cd "$DIR"

count=0
echo "=== BAD: for f in \$(ls) ==="
for f in $(ls); do
  echo "  f = [$f]"
  count=$((count + 1))
done
echo "total iteraciones: $count"
echo "(archivos reales en el directorio: $(find . -maxdepth 1 -mindepth 1 | wc -l))"
