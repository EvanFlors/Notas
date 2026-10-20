#!/usr/bin/env bash
# Structural validation for sec-07-02-custom-checkov-policy.
#
# Note: no `set -o pipefail` on purpose — several checks pipe into grep -q
# which emits SIGPIPE (141) on early match; pipefail would surface that as FAIL.
set -eu

BASE="${1:-/tmp/sec-07-custom-policy}"
POLICY="$BASE/checks/BucketMustHaveClassification.py"
GOOD="$BASE/fixtures/good.tf"
BAD="$BASE/fixtures/bad.tf"
fail=0

echo "== Structural validation for $BASE =="

for p in "$POLICY" "$GOOD" "$BAD"; do
  if [ -f "$p" ]; then
    echo "  OK   present: ${p#$BASE/}"
  else
    echo "  FAIL missing: ${p#$BASE/}"
    fail=$((fail+1))
  fi
done

# ----- Policy content -----
if grep -q 'id="CKV_ACME_1"' "$POLICY" 2>/dev/null; then
  echo "  OK   policy declares id=\"CKV_ACME_1\""
else
  echo "  FAIL policy must declare id=\"CKV_ACME_1\" (ORG-prefixed to avoid collision)"
  fail=$((fail+1))
fi

if grep -q 'BaseResourceCheck' "$POLICY" 2>/dev/null; then
  echo "  OK   policy extends BaseResourceCheck"
else
  echo "  FAIL policy must extend BaseResourceCheck"
  fail=$((fail+1))
fi

if grep -q 'aws_s3_bucket' "$POLICY" 2>/dev/null; then
  echo "  OK   policy targets aws_s3_bucket"
else
  echo "  FAIL policy must list aws_s3_bucket in supported_resources"
  fail=$((fail+1))
fi

if grep -q 'ALLOWED_CLASSIFICATIONS' "$POLICY" 2>/dev/null; then
  echo "  OK   policy defines ALLOWED_CLASSIFICATIONS enum"
else
  echo "  FAIL policy must define ALLOWED_CLASSIFICATIONS enum"
  fail=$((fail+1))
fi

# ----- Import smoke test (does not require checkov) -----
scratch=$(mktemp -d /tmp/sec-07-02-import.XXXXXX)
trap 'rm -rf "$scratch"' EXIT
if ( cd "$BASE/checks" && python3 -c "import BucketMustHaveClassification; print('OK')" ) >"$scratch/import.log" 2>&1; then
  echo "  OK   policy imports cleanly under python3"
else
  echo "  FAIL policy does not import cleanly:"
  sed 's/^/       /' "$scratch/import.log"
  fail=$((fail+1))
fi

# ----- Fixtures sanity -----
if grep -q 'data_classification *= *"internal"' "$GOOD" 2>/dev/null; then
  echo "  OK   good.tf has valid data_classification value"
else
  echo "  FAIL good.tf should set data_classification to an allowed value (e.g. internal)"
  fail=$((fail+1))
fi

bad_count=$(grep -c '^resource "aws_s3_bucket"' "$BAD" 2>/dev/null || echo 0)
# Scrub whitespace/newlines from grep -c (BSD/GNU differences).
bad_count="${bad_count//[^0-9]/}"
if [ "${bad_count:-0}" -ge 2 ]; then
  echo "  OK   bad.tf has at least 2 failing resources ($bad_count found)"
else
  echo "  FAIL bad.tf must have at least 2 failing resources (found ${bad_count:-0})"
  fail=$((fail+1))
fi

# ----- Optional: run checkov twice if available -----
if command -v checkov >/dev/null 2>&1; then
  echo "  INFO checkov is installed; running smoke test (twice)"
  for i in 1 2; do
    out="$scratch/checkov-$i.txt"
    ( cd "$BASE" && checkov -d fixtures/ --external-checks-dir ./checks \
        --check CKV_ACME_1 --compact ) >"$out" 2>&1 || true
    if grep -q 'FAILED for resource: aws_s3_bucket' "$out"; then
      echo "  OK   run $i: checkov reports FAILED on bad.tf resources"
    else
      echo "  FAIL run $i: checkov did not flag any aws_s3_bucket in bad.tf"
      sed 's/^/       /' "$out" | head -20
      fail=$((fail+1))
    fi
  done
else
  echo "  SKIP checkov not installed; structural + import checks only."
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md."
exit 0
