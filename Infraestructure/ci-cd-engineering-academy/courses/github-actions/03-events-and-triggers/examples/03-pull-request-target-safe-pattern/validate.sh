#!/usr/bin/env bash
# Validate that no .yml in this example contains the pull_request_target
# anti-pattern (checkout of PR head).
#
# Note: no `set -o pipefail` — grep over multi-line producers can SIGPIPE.

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

ok=0; fail=0
log() { echo "  $1"; }

for f in *.yml; do
  [ -e "$f" ] || continue
  if python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null; then
    log "OK   — $f parses as YAML"; ok=$((ok+1))
  else
    log "FAIL — $f is not valid YAML"; fail=$((fail+1))
  fi
done

# The critical check: for any .yml that uses pull_request_target, there must
# NOT be an actions/checkout referencing github.event.pull_request.head.*
for f in *.yml; do
  [ -e "$f" ] || continue
  if grep -q 'pull_request_target' "$f"; then
    if grep -A3 'actions/checkout' "$f" | grep -q 'pull_request\.head'; then
      log "FAIL — $f uses pull_request_target AND checks out PR head (ANTI-PATTERN)"
      fail=$((fail+1))
    else
      log "OK   — $f (pull_request_target) does not checkout PR head"
      ok=$((ok+1))
    fi
  fi
done

# pr-labeler should declare permissions explicitly
if grep -q '^permissions:' pr-labeler.yml; then
  log "OK   — pr-labeler.yml declares explicit permissions"; ok=$((ok+1))
else
  log "FAIL — pr-labeler.yml missing explicit permissions"; fail=$((fail+1))
fi

# report workflow should use workflow_run, not pull_request_target
if grep -q 'workflow_run:' pr-test-and-report.yml; then
  log "OK   — pr-test-and-report.yml uses workflow_run"; ok=$((ok+1))
else
  log "FAIL — pr-test-and-report.yml should use workflow_run"; fail=$((fail+1))
fi

if command -v actionlint >/dev/null 2>&1; then
  if actionlint *.yml >/dev/null 2>&1; then
    log "OK   — actionlint clean on all .yml"; ok=$((ok+1))
  else
    log "FAIL — actionlint reported issues"; fail=$((fail+1))
  fi
else
  log "SKIP — actionlint not installed"
fi

echo
echo "RESULT: $ok OK, $fail FAIL."
[ "$fail" -eq 0 ]
