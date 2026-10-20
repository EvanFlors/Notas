#!/usr/bin/env bash
# Validate k8s-17-02-upgrade-managed-cluster-adr: structure of the ADR.
#
# NOTE: we deliberately do NOT enable `set -o pipefail` because some checks
# pipe into `grep -q`, and grep closing the pipe early produces SIGPIPE on
# the upstream which pipefail would misreport as failure.

# Where to look for the ADR. Priority:
#   1. $ADR_FILE environment variable
#   2. starter/ADR-001-upgrade-strategy.md relative to activity root
#   3. solution/ADR-001-upgrade-strategy.md (so the reference ADR also validates)

HERE="$(cd "$(dirname "$0")" && pwd)"
ACTIVITY_ROOT="$(cd "$HERE/.." && pwd)"

CANDIDATES=(
  "${ADR_FILE:-}"
  "$ACTIVITY_ROOT/starter/ADR-001-upgrade-strategy.md"
  "$ACTIVITY_ROOT/solution/ADR-001-upgrade-strategy.md"
)

ADR=""
for cand in "${CANDIDATES[@]}"; do
  if [ -n "$cand" ] && [ -f "$cand" ]; then
    ADR="$cand"
    break
  fi
done

if [ -z "$ADR" ]; then
  echo "FAIL: ADR file not found."
  echo "Looked in:"
  for cand in "${CANDIDATES[@]}"; do
    [ -n "$cand" ] && echo "  - $cand"
  done
  echo "Create starter/ADR-001-upgrade-strategy.md and re-run."
  exit 1
fi

echo "== Validating ADR at: $ADR =="

pass=0
fail=0
report=""

ok() { report+="  OK   $1\n"; pass=$((pass+1)); }
ko() { report+="  FAIL $1\n"; fail=$((fail+1)); }

content="$(cat "$ADR")"

# 1. Title begins with "# ADR-001:"
first_line="$(head -n1 "$ADR")"
if echo "$first_line" | grep -qE '^# ADR-001:'; then
  ok "title starts with '# ADR-001:'"
else
  ko "title must start with '# ADR-001:' (got: '$first_line')"
fi

# 2–8. Required sections (exact Markdown headings)
sections=(
  "## Status"
  "## Context"
  "## Decision"
  "## Consequences"
  "## Alternatives Considered"
  "## RPO and RTO"
  "## Rollback Plan"
  "## Success Metrics"
)
for s in "${sections[@]}"; do
  if printf "%s\n" "$content" | grep -qxF "$s"; then
    ok "section present: '$s'"
  else
    ko "section missing: '$s'"
  fi
done

# 9. Decision mentions in-place OR blue/green explicitly
# (case-insensitive). We take only the Decision section content.
decision_block="$(awk '
  /^## Decision$/ {capture=1; next}
  /^## / {capture=0}
  capture {print}
' "$ADR")"

if echo "$decision_block" | grep -qiE 'in-place|blue/green|blue-green'; then
  ok "Decision contains 'in-place' or 'blue/green'"
else
  ko "Decision must contain the literal 'in-place' or 'blue/green'"
fi

# 10. Alternatives Considered: at least 2 bullets
alt_block="$(awk '
  /^## Alternatives Considered$/ {capture=1; next}
  /^## / {capture=0}
  capture {print}
' "$ADR")"
alt_count="$(printf "%s\n" "$alt_block" | grep -cE '^[-*] ')"
if [ "${alt_count:-0}" -ge 2 ]; then
  ok "Alternatives Considered lists $alt_count option(s) (>=2)"
else
  ko "Alternatives Considered must list >=2 bulleted options (found $alt_count)"
fi

# 11. RPO/RTO section contains at least one number
rpo_block="$(awk '
  /^## RPO and RTO$/ {capture=1; next}
  /^## / {capture=0}
  capture {print}
' "$ADR")"
if echo "$rpo_block" | grep -qE '[0-9]'; then
  ok "RPO and RTO contains numeric value(s)"
else
  ko "RPO and RTO must include numeric target(s)"
fi

echo
printf "%b" "$report"
echo
echo "SUMMARY: $pass passed, $fail failed."

if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
