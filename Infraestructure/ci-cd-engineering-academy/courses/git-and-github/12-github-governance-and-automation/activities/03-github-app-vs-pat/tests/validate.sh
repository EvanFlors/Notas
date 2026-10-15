#!/usr/bin/env bash
# Validate the ADR structure for gh-12-03-github-app-vs-pat.
# No `set -o pipefail` — we use grep extensively.

DIR="${1:-${SCRATCH_DIR:-/tmp/adr-identity}}"
fail=0
ADR="$DIR/ADR.md"

echo "== Validating $ADR =="
if [ ! -f "$ADR" ]; then
  echo "FAIL: ADR.md missing. Run starter/build-scratch.sh and edit it."
  exit 1
fi

# 1) No remaining <TODO: ...> placeholders
if grep -q "<TODO" "$ADR"; then
  n=$(grep -c "<TODO" "$ADR")
  echo "  FAIL $n unresolved <TODO...> placeholder(s)"
  fail=$((fail+1))
else
  echo "  OK   no <TODO...> placeholders left"
fi

# 2) Required sections present
need_section() {
  local heading="$1"
  if grep -qE "^#{1,3}[[:space:]]+$heading" "$ADR"; then
    echo "  OK   section '$heading' present"
  else
    echo "  FAIL section '$heading' missing"
    fail=$((fail+1))
  fi
}
need_section "Context"
need_section "Decision"
need_section "Consequences"
need_section "Alternatives considered"
need_section "Compliance mapping"

# 3) Length between 300 and 1200 words (soft upper bound)
words=$(wc -w < "$ADR" | tr -d ' ')
if [ "$words" -ge 300 ] && [ "$words" -le 1200 ]; then
  echo "  OK   length $words words (300–1200)"
else
  echo "  FAIL length $words words (expected 300–1200)"
  fail=$((fail+1))
fi

# 4) At least one of GitHub App / OIDC mentioned in Decision area
#    (grep over whole file is enough as long as word appears somewhere)
if grep -qE "GitHub App|OIDC" "$ADR"; then
  echo "  OK   decision mentions GitHub App or OIDC"
else
  echo "  FAIL productive decision should include GitHub App and/or OIDC"
  fail=$((fail+1))
fi

# 5) At least 2 alternatives explicitly rejected (crude: must contain the word
#    "rejected" OR "descartad" OR "why not" at least twice).
rejected_hits=$(grep -ciE "rejected|descartad|why not|no se elige|discarded" "$ADR")
if [ "$rejected_hits" -ge 2 ]; then
  echo "  OK   at least 2 rejection rationales found ($rejected_hits hits)"
else
  echo "  FAIL need at least 2 rejection rationales (found $rejected_hits)"
  fail=$((fail+1))
fi

# 6) Compliance table lines: look for 3 rows after the Compliance heading
rows_in_compliance=$(awk '
  /^#{1,3}[[:space:]]+Compliance mapping/ {inside=1; next}
  /^#{1,3}[[:space:]]+/ {inside=0}
  inside && /^\|/ {n++}
  END {print n+0}
' "$ADR")
# Expect: header row + separator + 3 data rows = 5 rows
if [ "$rows_in_compliance" -ge 5 ]; then
  echo "  OK   compliance table has >=3 data rows ($rows_in_compliance total rows)"
else
  echo "  FAIL compliance table too small ($rows_in_compliance rows; need header + sep + >=3)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: ADR estructuralmente completo."
exit 0
