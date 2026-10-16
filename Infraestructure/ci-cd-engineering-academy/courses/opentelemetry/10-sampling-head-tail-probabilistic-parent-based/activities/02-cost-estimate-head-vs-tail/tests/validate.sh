#!/usr/bin/env bash
# Validate that the student filled in analysis.md.
# Note: NO `set -o pipefail`; some pipes feed `grep -q` which may SIGPIPE.
set -eu

TARGET="${1:-starter/analysis.md}"

if [ ! -f "$TARGET" ]; then
  echo "FAIL: no existe $TARGET. Copia starter/TEMPLATE.md a starter/analysis.md y rellénalo."
  exit 1
fi

issues=0

# Must not be an untouched copy of the template
if grep -q "RELLENAR" "$TARGET"; then
  n=$(grep -c "RELLENAR" "$TARGET" || true)
  echo "FAIL: aún quedan $n marcadores 'RELLENAR' sin rellenar."
  issues=$((issues+1))
fi

check_keyword() {
  local kw="$1"
  if ! grep -qi "$kw" "$TARGET"; then
    echo "FAIL: falta mención a '$kw' en el análisis."
    issues=$((issues+1))
  fi
}

check_keyword "memoria"
check_keyword "decision_wait"
# "blind spot" o "ciego"
if ! grep -qi "blind spot" "$TARGET" && ! grep -qi "ciego" "$TARGET"; then
  echo "FAIL: falta mención a 'blind spot' o 'ciego' (observabilidad perdida)."
  issues=$((issues+1))
fi
check_keyword "recomend"

# Must mention the three strategies in a markdown table row
for s in A B C; do
  if ! grep -qE "^\|\s*${s}(\s|\|)" "$TARGET"; then
    echo "FAIL: falta fila de tabla para estrategia '$s'."
    issues=$((issues+1))
  fi
done

if [ "$issues" -eq 0 ]; then
  echo "OK"
  exit 0
fi
exit 1
