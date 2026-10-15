#!/usr/bin/env bash
# Structural validator for the manual-dispatch example.
#
# Note: no `set -o pipefail` — long producers piped into grep can SIGPIPE.

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

ok=0; fail=0
log() { echo "  $1"; }

if python3 -c "import yaml; yaml.safe_load(open('workflow.yml'))" 2>/dev/null; then
  log "OK   — workflow.yml parses"; ok=$((ok+1))
else
  log "FAIL — workflow.yml not valid YAML"; fail=$((fail+1))
fi

if grep -Eq 'workflow_dispatch:' workflow.yml; then
  log "OK   — declares workflow_dispatch"; ok=$((ok+1))
else
  log "FAIL — missing workflow_dispatch"; fail=$((fail+1))
fi

for t in 'type: choice' 'type: string' 'type: boolean'; do
  if grep -Fq "$t" workflow.yml; then
    log "OK   — uses $t"; ok=$((ok+1))
  else
    log "FAIL — missing $t input"; fail=$((fail+1))
  fi
done

if grep -q 'inputs\.environment' workflow.yml && grep -q 'inputs\.tag' workflow.yml; then
  log "OK   — inputs are consumed with inputs.*"; ok=$((ok+1))
else
  log "FAIL — inputs declared but not consumed"; fail=$((fail+1))
fi

if command -v actionlint >/dev/null 2>&1; then
  if actionlint workflow.yml >/dev/null 2>&1; then
    log "OK   — actionlint clean"; ok=$((ok+1))
  else
    log "FAIL — actionlint reported issues"; fail=$((fail+1))
  fi
else
  log "SKIP — actionlint not installed"
fi

echo
echo "RESULT: $ok OK, $fail FAIL."
[ "$fail" -eq 0 ]
