#!/usr/bin/env bash
# Structural + semantic validation for gcp-10-03-finops-unit-economics.
#
# Runs the student's python scripts against the synthetic CSVs and
# compares the printed number to the expected value with a tolerance.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/gcp-10-03-finops}"
fail=0

BILLING="$BASE/synthetic-billing.csv"
BUSINESS="$BASE/business-metrics.csv"
CPR="$BASE/cost_per_request.py"
CPC="$BASE/cost_per_customer.py"
DOC="$BASE/README-UNIT-ECONOMICS.md"

# Deterministic expected values for the starter CSVs.
EXPECTED_CPR="0.002280"
EXPECTED_CPC="4.560000"
TOLERANCE="0.00001"

echo "== Validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 required"
  exit 2
fi

for f in "$BILLING" "$BUSINESS" "$CPR" "$CPC" "$DOC"; do
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
  fi
done

run_numeric_check() {
  local script="$1"
  local expected="$2"
  local label="$3"
  if [ ! -f "$script" ]; then
    return
  fi
  local out
  if ! out=$(python3 "$script" "$BILLING" "$BUSINESS" 2>&1); then
    echo "  FAIL ${label}: script failed to run:"
    echo "       $out"
    fail=$((fail+1))
    return
  fi
  # Take the last non-empty line as the number.
  local num
  num=$(printf '%s\n' "$out" | awk 'NF {last=$0} END {print last}')
  python3 - "$num" "$expected" "$TOLERANCE" "$label" <<'PY' || fail=$((fail+1))
import sys
raw, expected, tol, label = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
try:
    v = float(raw.strip())
except Exception:
    print(f"  FAIL {label}: stdout last line '{raw}' is not a number")
    sys.exit(1)
if abs(v - float(expected)) <= float(tol):
    print(f"  OK   {label}: {v} == {expected} (+/- {tol})")
    sys.exit(0)
else:
    print(f"  FAIL {label}: got {v}, expected {expected} (+/- {tol})")
    sys.exit(1)
PY
}

run_numeric_check "$CPR" "$EXPECTED_CPR" "cost_per_request.py"
run_numeric_check "$CPC" "$EXPECTED_CPC" "cost_per_customer.py"

# README sections.
if [ -f "$DOC" ]; then
  for section in "Metodolog[ií]a|Methodology" \
                 "Cost +per +request|Coste +por +request" \
                 "Cost +per +(MAC|customer)|Coste +por +(MAC|customer|cliente)" \
                 "Interpretaci[oó]n|Interpretation"; do
    label="${section%%|*}"
    if grep -qiE "^#+ *(${section})" "$DOC"; then
      echo "  OK   README has '${label}' section"
    else
      echo "  FAIL README missing '${label}' section"
      fail=$((fail+1))
    fi
  done

  if grep -qiE 'coste +neto|net +cost|credits' "$DOC"; then
    echo "  OK   README explains net cost / credits"
  else
    echo "  FAIL README does not explain net cost / credits"
    fail=$((fail+1))
  fi

  if grep -qiE 'BigQuery' "$DOC"; then
    echo "  OK   README mentions BigQuery scale-up"
  else
    echo "  FAIL README does not mention BigQuery"
    fail=$((fail+1))
  fi

  if grep -qiE 'sesgo|bias|limitation|limitaci[oó]n' "$DOC"; then
    echo "  OK   README documents at least one bias / limitation"
  else
    echo "  FAIL README does not document a bias / limitation"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: unit economics calculados correctamente y README en forma."
exit 0
