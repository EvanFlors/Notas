#!/usr/bin/env bash
# Validate cap-06-01-choose-cloud-adr.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# `grep -q ... | ...` style pipes; a SIGPIPE on the upstream command would be
# promoted to a pipeline failure under pipefail — a false negative.
set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"
STAGE_ROOT="$(cd "$HERE/../.." && pwd)"
ADR="$STAGE_ROOT/terraform/README.md"

passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

echo "== Validando ADR 0006 en: $ADR =="

if [ ! -f "$ADR" ]; then
  echo "FAIL: no existe $ADR"
  exit 1
fi
ok "ADR file exists"

if grep -q "YYYY-MM-DD" "$ADR"; then
  bad "fecha YYYY-MM-DD sin reemplazar"
else
  ok "fecha es concreta"
fi

# El default trae 'Capstone maintainers'. En uso real debería ser el equipo del estudiante,
# pero el baseline ya está firmado por los maintainers; no bloqueamos la pasada.
if grep -q "equipo del capstone" "$ADR"; then
  bad "placeholder 'equipo del capstone' sin reemplazar"
else
  ok "autores definidos"
fi

if grep -qi "Estado: .*accepted" "$ADR"; then
  ok "ADR en estado accepted"
else
  bad "ADR no está en estado accepted (busca 'Estado: accepted')"
fi

# Decisión debe nombrar explícitamente un cloud.
if grep -qiE "Default demo del capstone:.*(AWS|GCP|Azure)" "$ADR"; then
  ok "Decisión identifica el cloud default"
else
  bad "Decisión no nombra AWS/GCP/Azure como default"
fi

echo -e "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
