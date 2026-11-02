#!/usr/bin/env bash
# Renombra fotos al patrón IMG_YYYYMMDD_HHMMSS.jpg usando mtime.
# Idempotente, --dry-run por defecto, --apply para ejecutar.
#
# Uso: rename.sh DIR [--dry-run|--apply]
set -euo pipefail
IFS=$'\n\t'

DIR=""
MODE="dry-run"

for arg in "$@"; do
  case "$arg" in
    --dry-run) MODE="dry-run" ;;
    --apply)   MODE="apply"   ;;
    -h|--help)
      sed -n '2,6p' "$0"; exit 0 ;;
    -*)
      echo "flag desconocida: $arg" >&2; exit 2 ;;
    *)
      if [[ -z $DIR ]]; then DIR="$arg"
      else echo "argumento inesperado: $arg" >&2; exit 2
      fi ;;
  esac
done

if [[ -z $DIR ]]; then
  echo "uso: $0 DIR [--dry-run|--apply]" >&2
  exit 2
fi
if [[ ! -d $DIR ]]; then
  echo "error: $DIR no es un directorio" >&2
  exit 1
fi

# Formatter portable de epoch -> YYYYMMDD_HHMMSS.
format_ts() {
  local epoch=$1
  if date -r "$epoch" '+%Y%m%d_%H%M%S' 2>/dev/null; then
    return
  fi
  date -d "@$epoch" '+%Y%m%d_%H%M%S'
}

# stat mtime portable.
stat_mtime() {
  local f=$1
  if stat -c '%Y' -- "$f" 2>/dev/null; then return; fi
  stat -f '%m' -- "$f"
}

renamed=0
skipped=0

# Iteramos sobre los jpg/jpeg del directorio con null-terminated.
# -iname es case-insensitive — cubre .JPG, .jpeg, etc.
while IFS= read -r -d '' src; do
  epoch=$(stat_mtime "$src")
  ts=$(format_ts "$epoch")
  base="IMG_${ts}"
  dst="$DIR/${base}.jpg"

  # Si ya coincide con el destino canónico, nada que hacer.
  if [[ "$src" == "$dst" ]]; then
    skipped=$((skipped + 1))
    continue
  fi

  # Resolución de colisiones: si el destino existe (y es otro archivo), probar _01, _02, ...
  if [[ -e $dst ]]; then
    i=1
    while :; do
      candidate=$(printf '%s/%s_%02d.jpg' "$DIR" "$base" "$i")
      if [[ "$src" == "$candidate" ]]; then
        # Ya tiene el nombre canónico con sufijo; no mover.
        dst="$candidate"
        break
      fi
      if [[ ! -e $candidate ]]; then
        dst="$candidate"
        break
      fi
      i=$((i + 1))
      if [[ $i -gt 999 ]]; then
        echo "ERROR: demasiadas colisiones para $base" >&2
        exit 1
      fi
    done
  fi

  if [[ "$src" == "$dst" ]]; then
    skipped=$((skipped + 1))
    continue
  fi

  if [[ $MODE == "apply" ]]; then
    mv -n -- "$src" "$dst"
    printf 'renombrado: %s -> %s\n' "$src" "$dst"
  else
    printf '[dry-run] %s -> %s\n' "$src" "$dst"
  fi
  renamed=$((renamed + 1))

done < <(find "$DIR" -maxdepth 1 -mindepth 1 -type f \
          \( -iname '*.jpg' -o -iname '*.jpeg' \) -print0 \
         | LC_ALL=C sort -z)

printf 'resumen: modo=%s renombrados=%d sin_cambio=%d\n' "$MODE" "$renamed" "$skipped"
