#!/usr/bin/env bash
# Procesa archivos regulares de DIR y escribe un reporte TSV con tamaño y ruta.
# Seguro ante nombres con espacios, newlines, asteriscos y pretensiones de inyección.
# Idempotente: reescribe el reporte en cada ejecución.
#
# Uso: process.sh DIR REPORT
set -euo pipefail
IFS=$'\n\t'

if [[ $# -ne 2 ]]; then
  echo "uso: $0 DIR REPORT" >&2
  exit 2
fi

DIR="$1"
REPORT="$2"

if [[ ! -d $DIR ]]; then
  echo "error: $DIR no es un directorio" >&2
  exit 1
fi

# Escribimos a un archivo temporal y hacemos rename atómico al final.
# Esto hace la operación idempotente y resistente a interrupciones.
tmp="$(mktemp "${REPORT}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

count=0
# find -maxdepth 1 => no recursivo. -type f => sólo regulares.
# IMPORTANTE: excluimos el propio REPORT para que la 2a ejecución sea idempotente.
while IFS= read -r -d '' f; do
  # Resolvemos a ruta absoluta sin seguir symlinks de componentes intermedios.
  abs="$(cd "$(dirname -- "$f")" && printf '%s/%s\n' "$(pwd)" "$(basename -- "$f")")"

  # Excluir el propio reporte si está dentro del directorio.
  if [[ $abs == "$(cd "$(dirname -- "$REPORT")" && pwd)/$(basename -- "$REPORT")" ]]; then
    continue
  fi

  # Tamaño en bytes. stat tiene flags distintos en Linux (-c) y BSD/macOS (-f).
  if size=$(stat -c '%s' -- "$f" 2>/dev/null); then
    :
  else
    size=$(stat -f '%z' -- "$f")
  fi

  printf '%s\t%s\n' "$size" "$abs" >> "$tmp"
  count=$((count + 1))
done < <(find "$DIR" -mindepth 1 -maxdepth 1 -type f -print0 | LC_ALL=C sort -z)

# Sort estable para idempotencia (dos ejecuciones -> mismo output).
mv -- "$tmp" "$REPORT"
trap - EXIT

echo "OK: procesados $count archivos. Reporte en $REPORT"
