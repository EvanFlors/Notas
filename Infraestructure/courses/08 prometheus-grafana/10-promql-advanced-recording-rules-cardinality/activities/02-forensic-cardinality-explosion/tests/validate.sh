#!/usr/bin/env bash
# Validate obs-10-02-forensic-cardinality-explosion.
# Checks that the student:
#   - preserved the evidence files
#   - added a metric_relabel_configs with action: drop targeting the offending metric
#   - used a specific regex (not a wildcard like .* or .+)
#   - wrote a FIX.md that mentions the offending metric and the label.
# Degrades gracefully: promtool check config is optional.
#
# NOTE: deliberately no 'set -o pipefail' because we grep -q several outputs below
# and pipefail would turn an early-closed pipe into a spurious failure.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"
STARTER="$ACT_DIR/starter"
PROM="$STARTER/prometheus.yml"
FIX="$STARTER/FIX.md"
EV_TSDB="$STARTER/evidence/tsdb-status.json"
EV_METRICS="$STARTER/evidence/metrics-sample.txt"

OFFENDER="checkout_requests_by_user_total"
BAD_LABEL="user_id"

fail=0
log() { echo "  $*"; }

echo "== Validating obs-10-02 forensic cardinality fix =="

# 1. Evidence preserved.
for f in "$EV_TSDB" "$EV_METRICS"; do
  if [ ! -f "$f" ]; then
    log "FAIL: evidence file missing: $f (do not delete evidence)"
    fail=$((fail+1))
  else
    log "OK  : evidence present: $(basename "$f")"
  fi
done

# 2. prometheus.yml exists.
if [ ! -f "$PROM" ]; then
  log "FAIL: $PROM not found."
  exit 1
fi
log "OK  : starter/prometheus.yml exists"

# 3. Contains metric_relabel_configs with action: drop.
if grep -q "metric_relabel_configs" "$PROM"; then
  log "OK  : metric_relabel_configs present"
else
  log "FAIL: metric_relabel_configs missing in prometheus.yml"
  fail=$((fail+1))
fi

if grep -q "action: drop" "$PROM"; then
  log "OK  : action: drop present"
else
  log "FAIL: 'action: drop' not present"
  fail=$((fail+1))
fi

# 4. The regex targets the offending metric by name.
if grep -Eq "regex:[[:space:]]*(['\"]?)${OFFENDER}\\1[[:space:]]*$" "$PROM"; then
  log "OK  : drop targets the offending metric name"
else
  log "FAIL: no 'regex: $OFFENDER' line found — the drop must name the offender"
  fail=$((fail+1))
fi

# 5. Reject wildcard regexes that would drop everything.
if grep -Eq 'regex:[[:space:]]*(["'\'']?)(\.\*|\.\+)\1[[:space:]]*$' "$PROM"; then
  log "FAIL: regex is too broad (.* or .+) — would drop everything"
  fail=$((fail+1))
else
  log "OK  : regex is not a broad wildcard"
fi

# 6. FIX.md exists and mentions the offender metric and the label.
if [ ! -f "$FIX" ]; then
  log "FAIL: $FIX not found — write a short FIX.md explaining the upstream fix"
  fail=$((fail+1))
else
  log "OK  : starter/FIX.md exists"
  if grep -q "$OFFENDER" "$FIX"; then
    log "OK  : FIX.md names the offending metric"
  else
    log "FAIL: FIX.md does not name the offending metric '$OFFENDER'"
    fail=$((fail+1))
  fi
  if grep -q "$BAD_LABEL" "$FIX"; then
    log "OK  : FIX.md names the offending label"
  else
    log "FAIL: FIX.md does not name the offending label '$BAD_LABEL'"
    fail=$((fail+1))
  fi
fi

# 7. Optional: promtool check config.
if command -v promtool >/dev/null 2>&1; then
  OUT_FILE="$(mktemp -t obs10-02.XXXXXX)"
  trap 'rm -f "$OUT_FILE"' EXIT
  if promtool check config "$PROM" >"$OUT_FILE" 2>&1; then
    log "OK  : promtool check config passed"
  else
    log "FAIL: promtool check config failed:"
    log "---- output ----"
    cat "$OUT_FILE"
    log "----------------"
    fail=$((fail+1))
  fi
else
  log "SKIP: promtool not installed — skipping 'check config' step"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: obs-10-02 forensic fix validated."
exit 0
