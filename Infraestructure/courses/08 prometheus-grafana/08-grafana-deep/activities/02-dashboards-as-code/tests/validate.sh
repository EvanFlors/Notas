#!/usr/bin/env bash
# Validate obs-08-02: dashboard.jsonnet must exist and parse; rendered.json must
# have uid + 6 panel types + 2 variables (query + custom).
#
# Note: no `set -o pipefail` to avoid SIGPIPE false positives when `grep -q`
# closes a pipe early on upstream commands (jq / jsonnet / cat).

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
STARTER="${1:-$ROOT/starter}"

JSONNET_SRC="$STARTER/dashboard.jsonnet"
RENDERED="$STARTER/rendered.json"
WORK="/tmp/obs-08-02-$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

passed=0
failed=0
skipped=0
report=""

ok()   { report+="  OK   $1\n"; passed=$((passed+1)); }
fail() { report+="  FAIL $1\n"; failed=$((failed+1)); }
skip() { report+="  SKIP $1\n"; skipped=$((skipped+1)); }

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required; install it and retry." >&2
  exit 2
fi

echo "== Checking jsonnet source at $JSONNET_SRC =="

if [ ! -f "$JSONNET_SRC" ]; then
  fail "dashboard.jsonnet missing — write it before validating"
else
  ok "dashboard.jsonnet exists"
  if command -v jsonnet >/dev/null 2>&1; then
    if jsonnet "$JSONNET_SRC" > "$WORK/parsed.json" 2> "$WORK/err.log"; then
      ok "dashboard.jsonnet parses with jsonnet"
      # if student forgot to run make render, we render here into a scratch file so we can keep validating
      if [ ! -f "$RENDERED" ]; then
        cp "$WORK/parsed.json" "$WORK/rendered.json"
        RENDERED="$WORK/rendered.json"
        skip "rendered.json not present; using fresh render for validation"
      fi
    else
      fail "jsonnet failed to parse dashboard.jsonnet (see $WORK/err.log)"
    fi
  else
    skip "jsonnet not installed; skipping parse check"
  fi
fi

echo
echo "== Checking rendered.json at $RENDERED =="

if [ ! -f "$RENDERED" ]; then
  fail "rendered.json missing — run 'make render' in starter/"
else
  if jq -e . "$RENDERED" >/dev/null 2>&1; then
    ok "rendered.json is valid JSON"

    uid="$(jq -r '.uid // ""' "$RENDERED")"
    if [ -n "$uid" ] && [ "$uid" != "null" ]; then
      ok "uid is set ('$uid')"
    else
      fail "uid missing in rendered.json"
    fi

    for t in timeseries stat gauge heatmap table state-timeline; do
      count="$(jq --arg t "$t" '[.panels[]? | select(.type==$t)] | length' "$RENDERED")"
      if [ "${count:-0}" -ge 1 ]; then
        ok "panel of type '$t' present"
      else
        fail "missing panel of type '$t'"
      fi
    done

    var_query="$(jq '[.templating.list[]? | select(.type=="query")] | length' "$RENDERED")"
    var_custom="$(jq '[.templating.list[]? | select(.type=="custom")] | length' "$RENDERED")"
    if [ "${var_query:-0}" -ge 1 ]; then ok "variable type 'query' present"; else fail "missing variable 'query'"; fi
    if [ "${var_custom:-0}" -ge 1 ]; then ok "variable type 'custom' present"; else fail "missing variable 'custom'"; fi
  else
    fail "rendered.json is not valid JSON"
  fi
fi

# Light DRY heuristic: jsonnet source should mention 'local' at least once
if [ -f "$JSONNET_SRC" ]; then
  if grep -q '^local ' "$JSONNET_SRC"; then
    ok "jsonnet uses 'local' bindings (likely DRY)"
  else
    fail "jsonnet has no 'local' bindings — likely 6 copy-pasted panels"
  fi
fi

echo
printf "%b" "$report"
echo
total=$((passed+failed+skipped))
echo "RESULT: $passed/$total checks OK ($failed failed, $skipped skipped)."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
