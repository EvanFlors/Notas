#!/usr/bin/env bash
# validate.sh — Verifica la actividad sys-17-01-select-menu-runbook.
# Uso: bash validate.sh [path/al/runbook.sh]
# Por defecto valida ../solution/runbook.sh.

set -o pipefail

SCRIPT="${1:-}"
if [[ -z "$SCRIPT" ]]; then
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SCRIPT="$here/../solution/runbook.sh"
fi

fail=0

echo "== Validando: $SCRIPT =="

if [[ ! -f "$SCRIPT" ]]; then
  echo "FAIL: no existe $SCRIPT"
  exit 1
fi

run() {
  # Alimenta stdin al script y captura stdout+stderr+exit.
  local input="$1"
  printf '%s' "$input" | bash "$SCRIPT" 2>&1
}

# 1. Opción 1 (status) → línea con "status" + exit limpio al pedir 4
out="$(run $'1\n4\n')" || true
if grep -qi 'status' <<<"$out"; then
  echo "  OK   opción 1 muestra 'status'"
else
  echo "  FAIL opción 1 no imprimió 'status'"
  fail=$((fail+1))
fi

# 2. Opción 2 (logs) → >= 3 líneas tras el prompt
out="$(run $'2\n4\n')" || true
log_lines=$(grep -ci 'logs' <<<"$out" || true)
if (( log_lines >= 3 )); then
  echo "  OK   opción 2 produce >=3 líneas con 'logs' ($log_lines)"
else
  echo "  FAIL opción 2 produce $log_lines líneas con 'logs' (esperado >=3)"
  fail=$((fail+1))
fi

# 3. Opción 3 + "n" → NO debe aparecer "OK"
out="$(run $'3\nn4\n')" || true
if grep -q 'OK' <<<"$out"; then
  echo "  FAIL opción 3 con 'n' reinició (apareció 'OK')"
  fail=$((fail+1))
else
  echo "  OK   opción 3 con 'n' NO reinicia"
fi

# 4. Opción 3 + "y" → debe aparecer "OK"
out="$(run $'3\ny4\n')" || true
if grep -q 'OK' <<<"$out"; then
  echo "  OK   opción 3 con 'y' reinicia (aparece 'OK')"
else
  echo "  FAIL opción 3 con 'y' no imprimió 'OK'"
  fail=$((fail+1))
fi

# 5. Opción 4 → exit 0
printf '4\n' | bash "$SCRIPT" >/dev/null 2>&1
rc=$?
if [[ $rc -eq 0 ]]; then
  echo "  OK   opción 4 termina con exit 0"
else
  echo "  FAIL opción 4 termina con exit $rc"
  fail=$((fail+1))
fi

echo
if (( fail > 0 )); then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad sys-17-01 completada correctamente."
exit 0
