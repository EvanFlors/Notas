#!/usr/bin/env bash
# Structural validator for cap-14-01-k6-smoke-and-soak.
# Checks that the stage k6 artifacts exist and that baseline.md was filled
# with non-trivial content.
#
# NOTE: NOT using `set -o pipefail` to avoid SIGPIPE false-positives from pipes.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT="$(cd "$HERE/.." && pwd)"
STAGE="$(cd "$ACT/../.." && pwd)"
fail=0

check_file() {
  if [ -f "$1" ]; then
    echo "  OK   $1 exists"
  else
    echo "  FAIL $1 missing"
    fail=$((fail+1))
  fi
}

echo "== Validating cap-14-01-k6-smoke-and-soak =="

check_file "$STAGE/load/k6-script.js"
check_file "$STAGE/load/run-k6.sh"
check_file "$ACT/starter/baseline.md"

# run-k6.sh must handle SKIP when k6 is missing.
if grep -q "SKIP: k6 not installed" "$STAGE/load/run-k6.sh" 2>/dev/null; then
  echo "  OK   run-k6.sh contains SKIP branch for missing k6"
else
  echo "  FAIL run-k6.sh must SKIP when k6 is not installed"
  fail=$((fail+1))
fi

# k6 script must declare thresholds for p95 and error rate.
if grep -q "http_req_failed" "$STAGE/load/k6-script.js" \
   && grep -q "http_req_duration" "$STAGE/load/k6-script.js"; then
  echo "  OK   k6-script.js declares the required thresholds"
else
  echo "  FAIL k6-script.js must declare http_req_failed and http_req_duration thresholds"
  fail=$((fail+1))
fi

# Baseline check: look for the student's baseline.md (either edited in starter/
# or copied up to the activity root). Required sections must have been filled,
# i.e. not just the starter TODOs.
BASELINE=""
for cand in "$ACT/baseline.md" "$ACT/starter/baseline.md"; do
  if [ -f "$cand" ]; then BASELINE="$cand"; break; fi
done

if [ -z "$BASELINE" ]; then
  echo "  FAIL no baseline.md found"
  fail=$((fail+1))
else
  echo "  OK   baseline.md found at $BASELINE"
  for section in "p95" "Error rate" "Fecha"; do
    if grep -Eq "^##[[:space:]]+${section}" "$BASELINE"; then
      echo "  OK   baseline.md has section '## $section'"
    else
      echo "  FAIL baseline.md missing section '## $section'"
      fail=$((fail+1))
    fi
  done
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) found."
  exit 1
fi
echo "RESULT: 0 issue(s). Estructura valida."
exit 0
