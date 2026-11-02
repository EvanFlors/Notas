#!/usr/bin/env bash
# validate.sh — Verifica la actividad sys-17-02-dialog-based-installer.
# Uso: bash validate.sh [path/al/installer.sh]
# Por defecto valida ../solution/installer.sh.

set -o pipefail

SCRIPT="${1:-}"
if [[ -z "$SCRIPT" ]]; then
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SCRIPT="$here/../solution/installer.sh"
fi

fail=0
echo "== Validando: $SCRIPT =="

if [[ ! -f "$SCRIPT" ]]; then
  echo "FAIL: no existe $SCRIPT"
  exit 1
fi

# 1. --help imprime "Uso:" y exit 0
if bash "$SCRIPT" --help 2>&1 | grep -q '^Uso:'; then
  echo "  OK   --help imprime 'Uso:'"
else
  echo "  FAIL --help no imprime 'Uso:'"; fail=$((fail+1))
fi

# 2. --non-interactive sin --target debe fallar (exit != 0)
if bash "$SCRIPT" --non-interactive --components core --yes >/dev/null 2>&1; then
  echo "  FAIL falta --target no-interactivo pero devolvió exit 0"
  fail=$((fail+1))
else
  echo "  OK   falta --target no-interactivo falla"
fi

# 3. Flags completos → exit 0 + línea INSTALLED
out="$(bash "$SCRIPT" --target /tmp/sys17 --components core,cli --yes --non-interactive 2>&1)"
rc=$?
if (( rc == 0 )) && grep -q '^INSTALLED target=/tmp/sys17 components=core,cli$' <<<"$out"; then
  echo "  OK   instalación no-interactiva produce línea INSTALLED esperada"
else
  echo "  FAIL instalación no-interactiva. rc=$rc out:"
  echo "$out" | sed 's/^/    /'
  fail=$((fail+1))
fi

# 4. --force-fallback funciona aunque dialog/whiptail existan
out="$(bash "$SCRIPT" --force-fallback --target /tmp/sys17fb --components core --yes --non-interactive 2>&1)"
rc=$?
if (( rc == 0 )) && grep -q '^INSTALLED target=/tmp/sys17fb components=core$' <<<"$out"; then
  echo "  OK   --force-fallback no-interactivo también funciona"
else
  echo "  FAIL --force-fallback falló. rc=$rc out:"
  echo "$out" | sed 's/^/    /'
  fail=$((fail+1))
fi

# 5. Componente inválido debe fallar
if bash "$SCRIPT" --target /tmp/sys17bad --components core,noexiste --yes --non-interactive >/dev/null 2>&1; then
  echo "  FAIL componente inválido no abortó"
  fail=$((fail+1))
else
  echo "  OK   componente inválido abortó"
fi

echo
if (( fail > 0 )); then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad sys-17-02 completada correctamente."
exit 0
