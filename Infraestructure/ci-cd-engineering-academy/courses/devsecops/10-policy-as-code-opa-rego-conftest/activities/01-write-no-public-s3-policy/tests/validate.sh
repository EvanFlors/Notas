#!/usr/bin/env bash
# Structural + optional functional validation for sec-10-01-write-no-public-s3-policy.
# Checks that policy/s3.rego and policy/s3_test.rego exist and contain the
# minimum structural elements. If `opa` is available in PATH, also runs
# `opa test` over the policy directory.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/sec-10-01-no-public-s3}"
POLICY_DIR="$BASE/policy"
REGO="$POLICY_DIR/s3.rego"
TESTS="$POLICY_DIR/s3_test.rego"
fail=0

echo "== Validating sec-10-01-write-no-public-s3-policy at $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Create it first (see starter/)."
  exit 1
fi

# ---- Structural checks on s3.rego ----
if [ ! -f "$REGO" ]; then
  echo "  FAIL $REGO does not exist"
  fail=$((fail+1))
else
  echo "  OK   $REGO exists"
  if grep -qE '^package[[:space:]]+terraform\.s3' "$REGO"; then
    echo "  OK   s3.rego declares package terraform.s3"
  else
    echo "  FAIL s3.rego missing 'package terraform.s3'"
    fail=$((fail+1))
  fi
  if grep -qE '^import[[:space:]]+rego\.v1' "$REGO"; then
    echo "  OK   s3.rego uses 'import rego.v1'"
  else
    echo "  FAIL s3.rego missing 'import rego.v1'"
    fail=$((fail+1))
  fi
  deny_blocks=$(grep -cE '^deny[[:space:]]+contains' "$REGO" || true)
  if [ "$deny_blocks" -ge 2 ]; then
    echo "  OK   s3.rego has $deny_blocks deny rules (expected >=2)"
  else
    echo "  FAIL s3.rego has only $deny_blocks deny rules (expected >=2)"
    fail=$((fail+1))
  fi
  if grep -q 'sprintf' "$REGO"; then
    echo "  OK   s3.rego uses sprintf for messages"
  else
    echo "  FAIL s3.rego does not use sprintf (messages should be formatted)"
    fail=$((fail+1))
  fi
fi

# ---- Structural checks on s3_test.rego ----
if [ ! -f "$TESTS" ]; then
  echo "  FAIL $TESTS does not exist"
  fail=$((fail+1))
else
  echo "  OK   $TESTS exists"
  if grep -qE '^package[[:space:]]+terraform\.s3' "$TESTS"; then
    echo "  OK   s3_test.rego shares package terraform.s3"
  else
    echo "  FAIL s3_test.rego missing matching 'package terraform.s3'"
    fail=$((fail+1))
  fi
  tests_count=$(grep -cE '^test_' "$TESTS" || true)
  if [ "$tests_count" -ge 3 ]; then
    echo "  OK   s3_test.rego has $tests_count test_ rules (expected >=3)"
  else
    echo "  FAIL s3_test.rego has only $tests_count test_ rules (expected >=3)"
    fail=$((fail+1))
  fi
  if grep -q 'with input as' "$TESTS"; then
    echo "  OK   s3_test.rego uses 'with input as' for mocking"
  else
    echo "  FAIL s3_test.rego does not use 'with input as' (how else do you mock input?)"
    fail=$((fail+1))
  fi
fi

# ---- Optional functional check: opa test ----
if command -v opa >/dev/null 2>&1; then
  echo
  echo "== opa detected: running 'opa test $POLICY_DIR' =="
  if opa test "$POLICY_DIR"; then
    echo "  OK   opa test passed"
  else
    echo "  FAIL opa test reported failures"
    fail=$((fail+1))
  fi
else
  echo
  echo "  SKIP opa binary not found in PATH — functional check skipped."
  echo "       (Install with 'brew install opa' to run tests.)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara policy/ con solution/REFERENCE.md."
exit 0
