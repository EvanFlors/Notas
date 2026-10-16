#!/usr/bin/env bash
# Validate activity 02: dashboard.json has the required log-based metric query.
# No `set -o pipefail` on purpose.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/obs13-lab02}}"
DASH="$BASE/dashboard.json"
NOTES="$BASE/NOTES.md"
# The exact query the student must reference. Keep as plain string so a `grep -F`
# matches it anywhere in the JSON (serialized by jq or by hand).
REQUIRED_QUERY='sum(rate({app="api"} |= "ERROR" [5m]))'

passed=0
failed=0
report=""

if [ ! -d "$BASE" ]; then
  echo "SKIP: $BASE does not exist. Run starter/setup.sh first."
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq not installed; cannot validate JSON structure."
  exit 0
fi
if [ ! -f "$DASH" ]; then
  echo "FAIL: $DASH missing"; exit 1
fi

# 1. Valid JSON
if jq . "$DASH" >/dev/null 2>&1; then
  report+="dashboard.json is valid JSON: OK\n"; passed=$((passed+1))
else
  report+="dashboard.json is valid JSON: FAIL\n"; failed=$((failed+1))
fi

# 2. Required query present (extract via jq so JSON escaping is handled)
match_count="$(jq --arg q "$REQUIRED_QUERY" '
  [.panels[]?.targets[]?.expr // empty | select(. == $q)] | length
' "$DASH" 2>/dev/null || echo 0)"
if [ "${match_count:-0}" -ge 1 ]; then
  report+="required log-based metric query present: OK\n"; passed=$((passed+1))
else
  report+="required log-based metric query present: FAIL (expected literal: $REQUIRED_QUERY)\n"
  failed=$((failed+1))
fi

# 3. A panel referencing that query must have a loki datasource
has_loki_panel="$(jq --arg q "$REQUIRED_QUERY" '
  [.panels[]? |
    select((.targets // []) | map(.expr // "") | any(. == $q)) |
    (.datasource.type // .datasource // "")
  ] | map(select(. == "loki")) | length
' "$DASH" 2>/dev/null || echo 0)"
if [ "${has_loki_panel:-0}" -ge 1 ]; then
  report+="panel with query has loki datasource: OK\n"; passed=$((passed+1))
else
  report+="panel with query has loki datasource: FAIL\n"; failed=$((failed+1))
fi

# 4. Dashboard description non-empty
desc_len="$(jq -r '.description // "" | length' "$DASH" 2>/dev/null || echo 0)"
if [ "${desc_len:-0}" -ge 20 ]; then
  report+="dashboard description present (>=20 chars): OK\n"; passed=$((passed+1))
else
  report+="dashboard description present (>=20 chars): FAIL (len=$desc_len)\n"; failed=$((failed+1))
fi

# 5. NOTES.md non-trivial
if [ -f "$NOTES" ]; then
  n_len=$(wc -c < "$NOTES" | tr -d ' ')
  if [ "$n_len" -ge 50 ] && ! grep -q "^TODO:" "$NOTES"; then
    report+="NOTES.md has content (>=50 chars, no TODO): OK\n"; passed=$((passed+1))
  else
    report+="NOTES.md has content (>=50 chars, no TODO): FAIL\n"; failed=$((failed+1))
  fi
else
  report+="NOTES.md exists: FAIL\n"; failed=$((failed+1))
fi

echo "== Validating activity 02 under $BASE =="
echo
printf "%b" "$report"
echo
echo "RESULT: $passed/5 checks OK."
if [ "$failed" -gt 0 ]; then exit 1; fi
exit 0
