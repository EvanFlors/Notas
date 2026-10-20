#!/usr/bin/env bash
# Validate tf-12-02-write-rego-policy-no-public-s3.
#
# Two modes:
#  - If `conftest` is installed: run against both fixtures (good must pass, bad must fail).
#  - If not: structural grep on starter/policy/s3.rego — plus try solution/policy if the
#    student's starter has NOT been filled in yet (TODO markers still present).
#
# NOTE: deliberately no 'set -o pipefail' — we grep -q several things and pipefail
# would turn producer-side SIGPIPE into a spurious FAIL.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"
STARTER_POLICY="$ACT_DIR/starter/policy/s3.rego"
SOLUTION_POLICY="$ACT_DIR/solution/policy/s3.rego"
GOOD="$HERE/fixtures/plan-good.json"
BAD="$HERE/fixtures/plan-bad.json"

fail=0
log() { echo "  $*"; }

echo "== Validating tf-12-02 Rego policy =="

if [ ! -f "$GOOD" ] || [ ! -f "$BAD" ]; then
  log "FAIL: fixtures missing (plan-good.json / plan-bad.json)."
  exit 1
fi
log "OK  : fixtures present"

# Decide which policy to validate.
POLICY="$STARTER_POLICY"
if [ ! -f "$POLICY" ]; then
  log "FAIL: starter/policy/s3.rego not found. Create it."
  exit 1
fi

# If starter still contains only TODO markers (no actual rules), fall back to solution
# so the harness remains runnable in reference mode. We only count the FINAL result
# against starter, however: starter must pass on its own merits for the activity to be done.
starter_has_rules=0
if grep -q "^deny\[" "$STARTER_POLICY"; then
  starter_has_rules=1
fi

if [ "$starter_has_rules" -eq 0 ]; then
  log "WARN: starter/policy/s3.rego has no 'deny[...]' rules yet (student has not completed activity)."
  log "      Falling back to solution/policy/s3.rego for pipeline health check."
  if [ -f "$SOLUTION_POLICY" ]; then
    POLICY="$SOLUTION_POLICY"
  fi
  # We still count this as a soft fail so the activity shows as 'not done'.
  fail=$((fail+1))
fi

log "Using policy: $POLICY"

# Structural checks (always).
if grep -q "^package main" "$POLICY"; then
  log "OK  : package main declared"
else
  log "FAIL: policy must start with 'package main' (so conftest finds it by default)"
  fail=$((fail+1))
fi

if grep -q "public-read" "$POLICY"; then
  log "OK  : policy mentions 'public-read'"
else
  log "FAIL: policy must reference 'public-read' (rule 1)"
  fail=$((fail+1))
fi

if grep -q "aws_s3_bucket_public_access_block" "$POLICY"; then
  log "OK  : policy mentions 'aws_s3_bucket_public_access_block'"
else
  log "FAIL: policy must reference 'aws_s3_bucket_public_access_block' (rule 2)"
  fail=$((fail+1))
fi

# Count distinct deny rules (must be >= 2).
deny_count="$(grep -c '^deny\[' "$POLICY" || true)"
if [ "${deny_count:-0}" -ge 2 ]; then
  log "OK  : found $deny_count 'deny[...]' rules (>= 2 required)"
else
  log "FAIL: expected >= 2 'deny[...]' rules, found ${deny_count:-0}"
  fail=$((fail+1))
fi

# Behavioral checks via conftest if available.
if command -v conftest >/dev/null 2>&1; then
  log "conftest found — running behavioral checks"
  policy_dir="$(dirname "$POLICY")"

  # plan-good.json must PASS (exit 0, no denies).
  if conftest test --policy "$policy_dir" "$GOOD" >/tmp/tf1202-good.out 2>&1; then
    log "OK  : plan-good.json produced 0 denies"
  else
    log "FAIL: plan-good.json produced violations (should be clean)"
    sed 's/^/    /' /tmp/tf1202-good.out
    fail=$((fail+1))
  fi

  # plan-bad.json must FAIL (exit non-zero).
  if conftest test --policy "$policy_dir" "$BAD" >/tmp/tf1202-bad.out 2>&1; then
    log "FAIL: plan-bad.json produced 0 denies (public bucket NOT caught!)"
    sed 's/^/    /' /tmp/tf1202-bad.out
    fail=$((fail+1))
  else
    log "OK  : plan-bad.json produced violations as expected"
  fi

  rm -f /tmp/tf1202-good.out /tmp/tf1202-bad.out
else
  log "SKIP: conftest not installed — structural checks only."
  log "      Install: brew install conftest   # or follow https://www.conftest.dev/install/"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: tf-12-02 Rego policy validated."
exit 0
