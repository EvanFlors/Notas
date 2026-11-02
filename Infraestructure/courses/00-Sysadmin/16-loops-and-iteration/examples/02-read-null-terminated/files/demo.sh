#!/usr/bin/env bash
# Demuestra lectura null-terminated: find -print0 | mapfile -d ''.
set -euo pipefail
IFS=$'\n\t'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$HERE/tmp-nullterm"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

rm -rf "$TMP"
mkdir -p "$TMP"

# Nombres deliberadamente hostiles.
touch "$TMP/normal.txt"
touch "$TMP/with space.txt"
touch "$TMP/with  double  space.txt"
touch "$TMP/*.sh"
# Newline literal en el nombre (Bash permite $'\n' dentro de un string).
touch "$TMP/$(printf 'line1\nline2').txt"

echo "== archivos creados (ls -1b muestra los metacaracteres como \\...) =="
ls -1b -- "$TMP"
echo

echo "== leyendo con find -print0 | mapfile -d '' =="
# shellcheck disable=SC2207  # mapfile es exactamente la alternativa correcta
mapfile -d '' files < <(find "$TMP" -mindepth 1 -maxdepth 1 -print0)

echo "elementos en el array: ${#files[@]}"
echo

echo "== iteración =="
i=0
for f in "${files[@]}"; do
  i=$((i + 1))
  # printf '%q' muestra el nombre con los metacaracteres escapados — útil para auditar.
  printf '  [%d] %q\n' "$i" "$f"
done

echo
real_count=$(find "$TMP" -mindepth 1 -maxdepth 1 -print0 | tr -cd '\0' | wc -c)
echo "conteo real (NULs en find -print0): $real_count"

if [[ "${#files[@]}" -eq "$real_count" ]]; then
  echo "OK: el array contiene exactamente los archivos esperados."
else
  echo "FAIL: discrepancia entre array (${#files[@]}) y real ($real_count)."
  exit 1
fi
