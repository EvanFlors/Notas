#!/usr/bin/env bash
# Validate cap-01-02-pytest-coverage.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# pipe into `grep -q` which may exit early, causing SIGPIPE on the upstream
# command. pipefail would surface those as spurious failures.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/cap-01-02}}"
passed=0
failed=0
report=""

check_cov_file() {
  local name="coverage.txt present"
  local f="$BASE/coverage.txt"
  if [ -f "$f" ] && [ -s "$f" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — expected non-empty '$f'\n"
    failed=$((failed+1))
  fi
}

check_cov_threshold() {
  local name="coverage >= 80%"
  local f="$BASE/coverage.txt"
  if [ ! -f "$f" ]; then
    report+="$name: FAIL — coverage.txt missing\n"; failed=$((failed+1)); return
  fi
  # Look for a 'TOTAL ... NN%' line and parse the percent.
  local pct
  pct="$(grep -E '^TOTAL' "$f" | awk '{for(i=NF;i>0;i--) if ($i ~ /%$/){print $i; exit}}' | tr -d '%')"
  if [ -z "$pct" ]; then
    report+="$name: FAIL — no TOTAL ...% line in coverage.txt\n"; failed=$((failed+1)); return
  fi
  if [ "$pct" -ge 80 ] 2>/dev/null; then
    report+="$name: OK ($pct%)\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — got ${pct}% (<80)\n"
    failed=$((failed+1))
  fi
}

check_justification() {
  local name="JUSTIFICATION.md present"
  local f="$BASE/JUSTIFICATION.md"
  if [ -f "$f" ] && [ -s "$f" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — expected non-empty '$f'\n"
    failed=$((failed+1))
  fi
}

echo "== Validating cap-01-02-pytest-coverage under $BASE =="
if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Follow README.md first."
  exit 1
fi

check_cov_file
check_cov_threshold
check_justification

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/3 checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
