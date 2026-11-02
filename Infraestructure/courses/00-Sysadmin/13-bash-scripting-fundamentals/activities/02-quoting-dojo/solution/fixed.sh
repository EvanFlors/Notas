#!/usr/bin/env bash
#
# fixed.sh — copia archivos que matchean un patron, de forma robusta.
#
# Uso:
#   fixed.sh <src> <dst> <pattern>
#
# Ejemplo:
#   fixed.sh /var/log /tmp/backup '*.log'
#
# Maneja correctamente nombres con espacios, globs literales y newlines.

set -euo pipefail

src="${1:?Uso: $0 <src> <dst> <pattern>}"
dst="${2:?Uso: $0 <src> <dst> <pattern>}"
pattern="${3:?Uso: $0 <src> <dst> <pattern>}"

[[ -d "$src" ]] || { printf 'Error: src no es un directorio: %s\n' "$src" >&2; exit 2; }
[[ -d "$dst" ]] || { printf 'Error: dst no es un directorio: %s\n' "$dst" >&2; exit 2; }

printf 'Procesando %s con patron %s\n' "$src" "$pattern"

count=0
while IFS= read -r -d '' f; do
  cp -- "$f" "$dst/"
  count=$((count + 1))
done < <(find "$src" -type f -name "$pattern" -print0)

printf 'Copiados %d archivos\n' "$count"
