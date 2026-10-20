#!/usr/bin/env bash
# Validate cap-08-03-adr-managed-k8s-choice.
#
# NOTE: deliberately NO `set -o pipefail`. Grep en pipelines con
# pipefail reportaria SIGPIPE (141) espurio cuando grep sale pronto.
set -eu

ACT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

note_ok()   { echo "  OK   -- $1"; }
note_fail() { echo "  FAIL -- $1"; fail=$((fail+1)); }

echo "== Validating cap-08-03-adr-managed-k8s-choice =="

adr="$ACT_DIR/ADR-001-managed-k8s.md"
if [ -f "$adr" ]; then
  note_ok "ADR-001-managed-k8s.md presente"
  for section in "Context" "Decision" "Consequences"; do
    if grep -Eq "(^|\s)#+\s*${section}" "$adr"; then
      note_ok "ADR tiene seccion '$section'"
    else
      note_fail "ADR no tiene seccion '$section'"
    fi
  done
  words="$(wc -w < "$adr" | tr -d ' ')"
  if [ "$words" -ge 300 ]; then
    note_ok "ADR >=300 palabras (visto: $words)"
  else
    note_fail "ADR corto: $words palabras (requerido >=300)"
  fi
else
  echo "  WARN -- ADR-001-managed-k8s.md ausente (entregable del estudiante)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s)."
  exit 1
fi
echo "RESULT: 0 issue(s)."
exit 0
