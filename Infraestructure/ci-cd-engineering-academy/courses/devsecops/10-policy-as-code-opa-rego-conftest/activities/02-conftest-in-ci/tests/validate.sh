#!/usr/bin/env bash
# Structural + optional functional validation for sec-10-02-conftest-in-ci.
# Checks the directory layout, the two policies, the wrapper script's
# essential properties, and (if conftest is installed) runs the wrapper
# and asserts that it reports violations.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/sec-10-02-conftest-ci}"
fail=0

echo "== Validating sec-10-02-conftest-in-ci at $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Create it first (see starter/)."
  exit 1
fi

# ---- Directory layout ----
for d in inputs policy policy/k8s policy/terraform; do
  if [ -d "$BASE/$d" ]; then
    echo "  OK   dir $d/ exists"
  else
    echo "  FAIL dir $d/ missing"
    fail=$((fail+1))
  fi
done

# ---- Inputs: must have at least one yaml and one json ----
yaml_count=$(find "$BASE/inputs" -maxdepth 1 -type f -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ')
json_count=$(find "$BASE/inputs" -maxdepth 1 -type f -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
if [ "$yaml_count" -ge 1 ]; then
  echo "  OK   inputs/ has >=1 .yaml file ($yaml_count)"
else
  echo "  FAIL inputs/ has no .yaml file"
  fail=$((fail+1))
fi
if [ "$json_count" -ge 1 ]; then
  echo "  OK   inputs/ has >=1 .json file ($json_count)"
else
  echo "  FAIL inputs/ has no .json file"
  fail=$((fail+1))
fi

# ---- Policies ----
check_rego() {
  local f="$1" expected_pkg="$2"
  if [ ! -f "$f" ]; then
    echo "  FAIL $f missing"
    fail=$((fail+1))
    return
  fi
  echo "  OK   $f exists"
  if grep -qE "^package[[:space:]]+${expected_pkg}" "$f"; then
    echo "  OK   $(basename "$f") declares package $expected_pkg"
  else
    echo "  FAIL $(basename "$f") missing 'package $expected_pkg'"
    fail=$((fail+1))
  fi
  if grep -qE '^import[[:space:]]+rego\.v1' "$f"; then
    echo "  OK   $(basename "$f") uses import rego.v1"
  else
    echo "  FAIL $(basename "$f") missing 'import rego.v1'"
    fail=$((fail+1))
  fi
  if grep -qE '^deny[[:space:]]+contains' "$f"; then
    echo "  OK   $(basename "$f") has a deny rule"
  else
    echo "  FAIL $(basename "$f") has no 'deny contains ...' rule"
    fail=$((fail+1))
  fi
}

# Find first .rego under each dir rather than hardcoding filename.
k8s_rego=$(find "$BASE/policy/k8s" -maxdepth 1 -type f -name '*.rego' 2>/dev/null | head -n1)
tf_rego=$(find "$BASE/policy/terraform" -maxdepth 1 -type f -name '*.rego' 2>/dev/null | head -n1)

if [ -n "$k8s_rego" ]; then
  check_rego "$k8s_rego" 'k8s\.'
else
  echo "  FAIL no .rego under policy/k8s/"
  fail=$((fail+1))
fi
if [ -n "$tf_rego" ]; then
  check_rego "$tf_rego" 'terraform\.'
else
  echo "  FAIL no .rego under policy/terraform/"
  fail=$((fail+1))
fi

# ---- Wrapper script ----
WRAPPER="$BASE/run-conftest.sh"
if [ ! -f "$WRAPPER" ]; then
  echo "  FAIL $WRAPPER missing"
  fail=$((fail+1))
else
  echo "  OK   run-conftest.sh exists"
  if [ -x "$WRAPPER" ]; then
    echo "  OK   run-conftest.sh is executable"
  else
    echo "  FAIL run-conftest.sh is not executable (chmod +x it)"
    fail=$((fail+1))
  fi
  if grep -qE '^set[[:space:]]+-eu' "$WRAPPER"; then
    echo "  OK   run-conftest.sh uses 'set -eu'"
  else
    echo "  FAIL run-conftest.sh missing 'set -eu'"
    fail=$((fail+1))
  fi
  if grep -q 'pipefail' "$WRAPPER"; then
    echo "  FAIL run-conftest.sh uses 'pipefail' — remove it (SIGPIPE caveat)"
    fail=$((fail+1))
  else
    echo "  OK   run-conftest.sh does NOT use pipefail"
  fi
  if grep -q 'command -v conftest' "$WRAPPER" || grep -q 'which conftest' "$WRAPPER"; then
    echo "  OK   run-conftest.sh checks for conftest availability (SKIP-gracefully)"
  else
    echo "  FAIL run-conftest.sh does not check if conftest is installed"
    fail=$((fail+1))
  fi
  if grep -q 'conftest' "$WRAPPER"; then
    echo "  OK   run-conftest.sh invokes conftest"
  else
    echo "  FAIL run-conftest.sh does not invoke conftest"
    fail=$((fail+1))
  fi
fi

# ---- Optional functional check ----
if command -v conftest >/dev/null 2>&1 && [ -f "$WRAPPER" ] && [ -x "$WRAPPER" ]; then
  echo
  echo "== conftest detected: running wrapper =="
  rc=0
  "$WRAPPER" >/tmp/sec-10-02-wrapper.out 2>&1 || rc=$?
  # We expect violations (rc != 0) since fixtures are intentionally bad.
  if [ "$rc" -ne 0 ]; then
    echo "  OK   wrapper exited $rc as expected (violations found)"
  else
    echo "  FAIL wrapper exited 0 but fixtures should have violations"
    echo "       (output in /tmp/sec-10-02-wrapper.out)"
    fail=$((fail+1))
  fi
else
  echo
  echo "  SKIP conftest not available or wrapper not executable — functional check skipped."
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
