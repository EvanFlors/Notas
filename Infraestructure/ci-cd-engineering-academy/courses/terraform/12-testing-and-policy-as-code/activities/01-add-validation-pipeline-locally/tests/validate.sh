#!/usr/bin/env bash
# Validate tf-12-01-add-validation-pipeline-locally.
# Checks: pre-apply.sh exists, is executable, runs cleanly against sample-module,
# emits per-layer PASS/FAIL/SKIP lines, and summary line. Handles missing tools gracefully.
#
# NOTE: deliberately no 'set -o pipefail' — we grep -q several outputs below,
# and pipefail would turn an early-closed pipe into a spurious failure.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"
SCRIPT="$ACT_DIR/starter/pre-apply.sh"
SAMPLE="$ACT_DIR/sample-module"

fail=0
log() { echo "  $*"; }

echo "== Validating tf-12-01 pipeline =="

if [ ! -f "$SCRIPT" ]; then
  log "FAIL: $SCRIPT not found. Create it following the README."
  exit 1
fi
log "OK  : starter/pre-apply.sh exists"

if [ ! -x "$SCRIPT" ]; then
  log "WARN: starter/pre-apply.sh is not executable; running with 'bash' anyway."
  log "      Fix with: chmod +x starter/pre-apply.sh"
fi

if [ ! -d "$SAMPLE" ]; then
  log "FAIL: sample-module/ missing — unexpected layout."
  exit 1
fi
log "OK  : sample-module/ present"

# Run the script against the sample module.
OUT_FILE="$(mktemp -t preapply-out.XXXXXX)"
trap 'rm -f "$OUT_FILE"' EXIT

if bash "$SCRIPT" "$SAMPLE" >"$OUT_FILE" 2>&1; then
  rc=0
else
  rc=$?
fi

log "exit code: $rc"

# The script must exit 0 when there are no hard FAILs (which is the case here
# because sample-module is clean; missing tools are SKIPed, not FAILed).
if [ "$rc" -ne 0 ]; then
  log "FAIL: script exited $rc on a clean sample module. Expected 0."
  log "---- script output ----"
  cat "$OUT_FILE"
  log "-----------------------"
  fail=$((fail+1))
fi

# Must emit at least one PASS or SKIP marker per layer label.
for label in "terraform fmt" "terraform init" "terraform validate" "tflint" "checkov" "conftest"; do
  if grep -q "$label" "$OUT_FILE"; then
    log "OK  : layer reported: $label"
  else
    log "FAIL: layer not reported in output: $label"
    fail=$((fail+1))
  fi
done

# Must print the summary line.
if grep -q "PASS=.* FAIL=.* SKIP=" "$OUT_FILE"; then
  log "OK  : summary line present"
else
  log "FAIL: summary line (PASS=.. FAIL=.. SKIP=..) missing"
  fail=$((fail+1))
fi

# Must have FAIL=0 on the clean sample module.
if grep -q "FAIL=0" "$OUT_FILE"; then
  log "OK  : no hard failures on clean sample"
else
  log "FAIL: expected FAIL=0 on sample-module"
  log "---- script output ----"
  cat "$OUT_FILE"
  log "-----------------------"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: tf-12-01 pipeline script validated."
exit 0
