#!/usr/bin/env bash
# Validate obs-09-01-write-alerts-with-promtool-tests.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks use
# `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep finds a
# match early. pipefail would spuriously mark those as failures.
#
# Behavior:
#   - Structural checks (alerts.yaml + tests.yaml exist, 3 required alertnames,
#     mandatory fields) always run.
#   - `promtool check rules` and `promtool test rules` are run if promtool is
#     available natively OR via docker. If neither is available, both are SKIP.
#
# Usage: bash tests/validate.sh [BASE_DIR]   (default: /tmp/obs-09-01)

BASE="${1:-/tmp/obs-09-01}"
fail=0
skip=0

echo "== Validating $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Did you copy the starter?"
  exit 1
fi

ALERTS="$BASE/alerts.yaml"
TESTS="$BASE/tests.yaml"

# -------- 1. Files present --------
for f in "$ALERTS" "$TESTS"; do
  if [ -f "$f" ]; then
    echo "  OK   $(basename "$f") present"
  else
    echo "  FAIL $(basename "$f") missing"
    fail=$((fail+1))
  fi
done

# -------- 2. Required alertnames --------
for alert in HighErrorRate HighLatencyP95 AbsentTarget; do
  if grep -q "alert: $alert" "$ALERTS" 2>/dev/null; then
    echo "  OK   alert '$alert' defined"
  else
    echo "  FAIL alert '$alert' missing"
    fail=$((fail+1))
  fi
done

# -------- 3. Mandatory fields per alert --------
for field in "for:" "severity:" "team:" "summary:" "description:" "runbook_url:"; do
  cnt=$(grep -c "$field" "$ALERTS" 2>/dev/null)
  if [ "${cnt:-0}" -ge 3 ]; then
    echo "  OK   field '$field' present (>=3 occurrences)"
  else
    echo "  FAIL field '$field' missing or <3 occurrences (found $cnt)"
    fail=$((fail+1))
  fi
done

# -------- 4. promtool rules + tests --------
PROMTOOL=""
if command -v promtool >/dev/null 2>&1; then
  PROMTOOL="promtool"
elif command -v docker >/dev/null 2>&1; then
  PROMTOOL="docker run --rm --entrypoint promtool -v $BASE:/w -w /w prom/prometheus:latest"
fi

if [ -z "$PROMTOOL" ]; then
  echo "  SKIP promtool not available (nor docker); install prometheus or docker to run"
  skip=$((skip+1))
else
  if $PROMTOOL check rules alerts.yaml >/tmp/obs-09-01-check.log 2>&1; then
    echo "  OK   promtool check rules"
  else
    echo "  FAIL promtool check rules (see /tmp/obs-09-01-check.log)"
    fail=$((fail+1))
  fi
  if $PROMTOOL test rules tests.yaml >/tmp/obs-09-01-test.log 2>&1; then
    echo "  OK   promtool test rules"
  else
    echo "  FAIL promtool test rules (see /tmp/obs-09-01-test.log)"
    fail=$((fail+1))
  fi
fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "== PASS == ($skip skipped)"
  exit 0
else
  echo "== FAIL == $fail failure(s), $skip skipped"
  exit 1
fi
