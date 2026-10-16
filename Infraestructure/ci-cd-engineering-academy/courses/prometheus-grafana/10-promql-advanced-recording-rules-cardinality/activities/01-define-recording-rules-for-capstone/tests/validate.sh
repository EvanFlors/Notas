#!/usr/bin/env bash
# Validate obs-10-01-define-recording-rules-for-capstone.
# Checks: starter/rules.yml exists, contains the 3 expected record names,
# promtool check rules passes, promtool test rules passes.
# Degrades with SKIP if promtool is not installed.
#
# NOTE: deliberately no 'set -o pipefail' because we grep -q several outputs below
# and pipefail would turn an early-closed pipe into a spurious failure.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"
RULES="$ACT_DIR/starter/rules.yml"
TESTS="$ACT_DIR/starter/rule_test.yml"

fail=0
log() { echo "  $*"; }

echo "== Validating obs-10-01 recording rules =="

if [ ! -f "$RULES" ]; then
  log "FAIL: $RULES not found."
  exit 1
fi
log "OK  : starter/rules.yml exists"

if [ ! -f "$TESTS" ]; then
  log "FAIL: $TESTS not found."
  exit 1
fi
log "OK  : starter/rule_test.yml exists"

# Required record names.
for name in \
  "job:http_requests:rate5m" \
  "job:http_errors:ratio5m" \
  "job:http_request_duration:p99_5m"; do
  if grep -q "record: $name" "$RULES"; then
    log "OK  : record present: $name"
  else
    log "FAIL: missing record: $name"
    fail=$((fail+1))
  fi
done

# The starter ships expr: 0 as placeholder. Treat an unmodified file as failure.
placeholders="$(grep -c '^[[:space:]]*expr: 0[[:space:]]*$' "$RULES" || true)"
if [ "$placeholders" -gt 0 ]; then
  log "FAIL: $placeholders rule(s) still have placeholder 'expr: 0'. Complete the TODOs."
  fail=$((fail+1))
else
  log "OK  : no placeholder expressions remain"
fi

if ! command -v promtool >/dev/null 2>&1; then
  log "SKIP: promtool not installed — skipping check/test rules steps."
  log "      Install Prometheus to run them. Structural checks already ran."
  echo
  if [ "$fail" -gt 0 ]; then
    echo "RESULT: $fail check(s) failed."
    exit 1
  fi
  echo "OK: structural checks passed (promtool skipped)."
  exit 0
fi

# Run from starter/ so relative paths in rule_test.yml resolve.
cd "$ACT_DIR/starter"

OUT_FILE="$(mktemp -t obs10-01.XXXXXX)"
trap 'rm -f "$OUT_FILE"' EXIT

if promtool check rules rules.yml >"$OUT_FILE" 2>&1; then
  log "OK  : promtool check rules passed"
else
  log "FAIL: promtool check rules failed"
  log "---- output ----"
  cat "$OUT_FILE"
  log "----------------"
  fail=$((fail+1))
fi

if promtool test rules rule_test.yml >"$OUT_FILE" 2>&1; then
  log "OK  : promtool test rules passed"
else
  log "FAIL: promtool test rules failed"
  log "---- output ----"
  cat "$OUT_FILE"
  log "----------------"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: obs-10-01 recording rules validated."
exit 0
