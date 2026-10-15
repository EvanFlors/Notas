#!/usr/bin/env bash
# Validate tf-14-01: 3 resources adopted into state, legacy files intact, clean plan.
#
# Usage:
#   bash validate.sh                # default workdir /tmp/tf14-act01
#   bash validate.sh /tmp/other     # explicit workdir
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# command output into `grep -q` which short-circuits on first match and produces
# SIGPIPE (exit 141) on the upstream — pipefail would spuriously mark those as
# failures.

WORKDIR="${1:-${WORKDIR:-/tmp/tf14-act01}}"
LEGACY_DIR="${LEGACY_DIR:-/tmp/tf14-act01-legacy}"
passed=0
failed=0
report=""

add_pass() { report+="  OK   $1\n"; passed=$((passed+1)); }
add_fail() { report+="  FAIL $1\n"; failed=$((failed+1)); }

echo "== Validating tf-14-01 at: $WORKDIR =="

if [ ! -d "$WORKDIR" ]; then
  echo "FAIL: workdir does not exist: $WORKDIR"
  echo "hint: run starter/bootstrap.sh first"
  exit 1
fi

cd "$WORKDIR"

# ---- 1. Legacy dir intact (3 files, unchanged content) ----
if [ -d "$LEGACY_DIR" ]; then
  n=$(find "$LEGACY_DIR" -maxdepth 1 -type f -name '*.conf' | wc -l | tr -d ' ')
  if [ "$n" = "3" ]; then
    add_pass "legacy dir has 3 .conf files"
  else
    add_fail "legacy dir has $n .conf files (expected 3)"
  fi
else
  add_fail "legacy dir missing: $LEGACY_DIR"
fi

for f in app-alpha.conf app-beta.conf app-gamma.conf; do
  if [ -f "$LEGACY_DIR/$f" ]; then
    add_pass "legacy file present: $f"
  else
    add_fail "legacy file missing: $f"
  fi
done

# ---- 2. tfstate exists ----
if [ -f "$WORKDIR/terraform.tfstate" ]; then
  add_pass "terraform.tfstate exists"
else
  add_fail "terraform.tfstate missing — did you run apply?"
fi

# ---- 3. State list contains exactly the 3 expected addresses ----
if command -v terraform >/dev/null 2>&1; then
  state_out="$(terraform state list 2>/dev/null || true)"
  for addr in local_file.app_alpha local_file.app_beta local_file.app_gamma; do
    if echo "$state_out" | grep -qx "$addr"; then
      add_pass "state contains: $addr"
    else
      add_fail "state missing: $addr"
    fi
  done

  # ---- 4. Plan reports no changes ----
  if terraform plan -input=false -detailed-exitcode -no-color >/tmp/tf14-act01-plan.out 2>&1; then
    add_pass "terraform plan: No changes (exit 0)"
  else
    code=$?
    if [ "$code" = "2" ]; then
      add_fail "terraform plan reports pending changes (exit 2)"
    else
      add_fail "terraform plan errored (exit $code) — see /tmp/tf14-act01-plan.out"
    fi
  fi
else
  add_fail "terraform not installed; cannot verify state/plan"
fi

# ---- 5. No leftover generated.tf (should have been renamed/cleaned) ----
if [ -f "$WORKDIR/generated.tf" ]; then
  add_fail "generated.tf still present — should be renamed/cleaned to adopted.tf"
else
  add_pass "no residual generated.tf"
fi

# ---- 6. adopted.tf (or some .tf besides imports/versions) exists ----
other_tf=$(find "$WORKDIR" -maxdepth 1 -type f -name '*.tf' ! -name 'imports.tf' ! -name 'versions.tf' | wc -l | tr -d ' ')
if [ "$other_tf" -ge 1 ]; then
  add_pass "cleaned HCL present (adopted.tf or similar)"
else
  add_fail "no cleaned HCL file beyond imports.tf/versions.tf"
fi

echo
printf "%b" "$report"
echo "---"
echo "passed: $passed   failed: $failed"
if [ "$failed" -gt 0 ]; then exit 1; fi
exit 0
