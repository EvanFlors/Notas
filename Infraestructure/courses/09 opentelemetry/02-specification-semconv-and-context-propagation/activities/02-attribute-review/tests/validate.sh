#!/usr/bin/env bash
# Validate the student's review.md for otel-02-02.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# use `grep -q` which closes the pipe early and can cause SIGPIPE on producers.

REVIEW="${REVIEW:-/tmp/otel-02-02-review/review.md}"
passed=0
failed=0
report=""

if [ ! -f "$REVIEW" ]; then
  echo "FAIL: $REVIEW not found. Run starter/build-proposal.sh and fill in your review." >&2
  exit 1
fi

check_contains() {
  local pattern="$1" label="$2"
  if grep -qiE "$pattern" "$REVIEW"; then
    report+="OK $label\n"; passed=$((passed+1))
  else
    report+="FAIL missing: $label\n"; failed=$((failed+1))
  fi
}

# Each of the 15 attribute names must appear.
for attr in \
  "service\.name" "service\.version" "deployment\.environment" \
  "k8s\.pod\.name" "http\.request\.method" "http\.response\.status_code" \
  "url\.full" "server\.address" "userEmail" "request_id" \
  "acme\.cart\.item_count" "acme\.cart\.total_cents" "password" \
  "http\.method" "timestampMs"; do
  check_contains "$attr" "mentions attribute $attr"
done

# At least 4 attributes must be REJECTed.
reject_count=$(grep -ciE "reject" "$REVIEW" || true)
if [ "$reject_count" -ge 4 ]; then
  report+="OK at least 4 REJECT verdicts ($reject_count)\n"; passed=$((passed+1))
else
  report+="FAIL need >= 4 REJECT verdicts, got $reject_count\n"; failed=$((failed+1))
fi

# At least 2 RESOURCE classifications.
resource_count=$(grep -ciE "resource" "$REVIEW" || true)
if [ "$resource_count" -ge 2 ]; then
  report+="OK at least 2 RESOURCE verdicts ($resource_count)\n"; passed=$((passed+1))
else
  report+="FAIL need >= 2 RESOURCE verdicts, got $resource_count\n"; failed=$((failed+1))
fi

# Must have a Final clean list section.
check_contains "final clean list" "has 'Final clean list' section"

# Must mention PII or similar reason.
check_contains "pii|personal|sensitive|secret|password" "mentions PII/secret reasoning"

# Must mention cardinality.
check_contains "cardinal" "mentions cardinality reasoning"

total=$((passed+failed))

echo "== otel-02-02 review validation =="
printf "%b" "$report"
echo
echo "RESULT: $passed/$total checks passed."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
echo "RESULT: OK"
exit 0
