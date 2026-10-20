#!/usr/bin/env bash
# Validate that both YAML workflows in this example are structurally correct.
#
# Note: deliberately no `set -o pipefail` — some checks grep over multi-line
# producers and SIGPIPE (exit 141) would spuriously count as failure.

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

ok=0
fail=0
log() { echo "  $1"; }

check_yaml_parses() {
  local f="$1"
  if python3 -c "import sys, yaml; yaml.safe_load(open('$f'))" 2>/dev/null; then
    log "OK   — $f parses as YAML"; ok=$((ok+1))
  else
    log "FAIL — $f is not valid YAML"; fail=$((fail+1))
  fi
}

check_has_on_trigger() {
  local f="$1"
  if grep -Eq '^(on|"on"):' "$f"; then
    log "OK   — $f declares on:"; ok=$((ok+1))
  else
    log "FAIL — $f missing on:"; fail=$((fail+1))
  fi
}

if command -v actionlint >/dev/null 2>&1; then
  if actionlint workflow-naive.yml workflow-safe.yml >/dev/null 2>&1; then
    log "OK   — actionlint happy with both workflows"; ok=$((ok+1))
  else
    log "FAIL — actionlint reported issues (run 'actionlint' for detail)"; fail=$((fail+1))
  fi
else
  log "SKIP — actionlint not installed (optional)"
fi

for f in workflow-naive.yml workflow-safe.yml; do
  check_yaml_parses "$f"
  check_has_on_trigger "$f"
done

echo
echo "RESULT: $ok OK, $fail FAIL."
[ "$fail" -eq 0 ]
