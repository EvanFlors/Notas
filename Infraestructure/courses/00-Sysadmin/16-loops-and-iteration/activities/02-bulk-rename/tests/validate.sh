#!/usr/bin/env bash
# Validación automática para sys-16-02-bulk-rename.
# Comprueba: dry-run no toca filesystem, apply renombra, segunda ejecución es no-op,
# todos los archivos finales siguen el patrón IMG_YYYYMMDD_HHMMSS(_NN)?.jpg,
# conteo pre/post coincide, shellcheck limpio.
#
# Uso: validate.sh [DIR]
set -euo pipefail
IFS=$'\n\t'

DIR="${1:-/tmp/sys16-photos}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP="$HERE/../starter/setup.sh"
SCRIPT="$HERE/../rename.sh"
if [[ ! -f $SCRIPT ]]; then
  SCRIPT="$HERE/../solution/rename.sh"
fi

fail=0

echo "== Validación sys-16-02 en $DIR =="

# Reset limpio
bash "$SETUP" "$DIR" >/dev/null

# Hash del contenido del directorio (nombres) antes del dry-run
pre_listing=$(find "$DIR" -maxdepth 1 -mindepth 1 -type f -print0 \
  | LC_ALL=C sort -z | tr '\0' '\n')
pre_count=$(printf '%s\n' "$pre_listing" | grep -c . || true)

# 1) Dry-run no debe tocar nada
bash "$SCRIPT" "$DIR" > /tmp/sys16-rename-dry 2>&1
post_dry=$(find "$DIR" -maxdepth 1 -mindepth 1 -type f -print0 \
  | LC_ALL=C sort -z | tr '\0' '\n')
if [[ "$pre_listing" == "$post_dry" ]]; then
  echo "  OK   --dry-run (default) no modifica el filesystem"
else
  echo "  FAIL --dry-run modificó archivos"
  diff <(echo "$pre_listing") <(echo "$post_dry") | head -30 || true
  fail=$((fail + 1))
fi

# 2) Apply
bash "$SCRIPT" "$DIR" --apply > /tmp/sys16-rename-apply1 2>&1
post_apply1=$(find "$DIR" -maxdepth 1 -mindepth 1 -type f -print0 \
  | LC_ALL=C sort -z | tr '\0' '\n')
post_count=$(printf '%s\n' "$post_apply1" | grep -c . || true)

if [[ $pre_count -eq $post_count ]]; then
  echo "  OK   conteo preservado tras --apply ($post_count archivos)"
else
  echo "  FAIL conteo cambió: $pre_count -> $post_count"
  fail=$((fail + 1))
fi

# Todos los nombres deben seguir el patrón
bad=$(printf '%s\n' "$post_apply1" \
  | awk -F/ '{print $NF}' \
  | grep -vE '^IMG_[0-9]{8}_[0-9]{6}(_[0-9]{2})?\.jpg$' || true)
if [[ -z $bad ]]; then
  echo "  OK   todos los archivos siguen IMG_YYYYMMDD_HHMMSS(_NN)?.jpg"
else
  echo "  FAIL archivos fuera de patrón:"
  echo "$bad" | sed 's/^/      /'
  fail=$((fail + 1))
fi

# 3) Segunda ejecución apply: idempotencia (no debe mover ningún archivo)
out2=$(bash "$SCRIPT" "$DIR" --apply 2>&1)
if echo "$out2" | grep -q '^renombrado:'; then
  echo "  FAIL segunda ejecución --apply movió archivos (no idempotente):"
  echo "$out2" | grep '^renombrado:' | sed 's/^/      /'
  fail=$((fail + 1))
else
  echo "  OK   segunda ejecución --apply es un no-op (idempotente)"
fi
post_apply2=$(find "$DIR" -maxdepth 1 -mindepth 1 -type f -print0 \
  | LC_ALL=C sort -z | tr '\0' '\n')
if [[ "$post_apply1" == "$post_apply2" ]]; then
  echo "  OK   listado estable entre apply #1 y apply #2"
else
  echo "  FAIL listado cambió entre apply #1 y apply #2"
  fail=$((fail + 1))
fi

# shellcheck
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$SCRIPT"; then
    echo "  OK   shellcheck limpio"
  else
    echo "  FAIL shellcheck reporta warnings en $SCRIPT"
    fail=$((fail + 1))
  fi
else
  echo "  SKIP shellcheck no instalado"
fi

rm -f /tmp/sys16-rename-dry /tmp/sys16-rename-apply1

echo
if [[ $fail -gt 0 ]]; then
  echo "RESULT: $fail check(s) fallaron."
  exit 1
fi
echo "OK: todas las validaciones pasaron."
