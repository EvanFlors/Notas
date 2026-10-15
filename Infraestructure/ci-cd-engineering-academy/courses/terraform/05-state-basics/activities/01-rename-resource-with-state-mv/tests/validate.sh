#!/usr/bin/env bash
# Validate tf-05-01-rename-resource-with-state-mv.
#
# Expects the student to have:
#   1. Copied starter/ to $WORK.
#   2. Run terraform init + apply there.
#   3. Renamed random_pet.old_name -> random_pet.new_name in main.tf.
#   4. Run `terraform state mv` so that terraform plan is a no-op.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks pipe
# into `grep -q`, which can produce SIGPIPE on upstream producers (exit 141)
# when the match is found early. pipefail would spuriously flag those as
# failures.

WORK="${1:-${WORK_DIR:-/tmp/tf-05-01-rename}}"
fail=0

echo "== Validating tf-05-01 at $WORK =="

if [ ! -d "$WORK" ]; then
  echo "FAIL: $WORK does not exist. Copy starter/ there and run through the activity first."
  exit 1
fi

cd "$WORK" || { echo "FAIL: cannot cd into $WORK"; exit 1; }

if ! command -v terraform >/dev/null 2>&1; then
  echo "FAIL: terraform is not installed or not in PATH."
  exit 1
fi

# 1) State file exists (local backend).
if [ ! -f terraform.tfstate ]; then
  echo "  FAIL no terraform.tfstate found — did you run 'terraform apply'?"
  fail=$((fail+1))
else
  echo "  OK   terraform.tfstate present"
fi

# 2) State lists random_pet.new_name and NOT random_pet.old_name.
state_list="$(terraform state list 2>/dev/null || true)"

has_new=0
has_old=0
if printf '%s\n' "$state_list" | grep -qx 'random_pet.new_name'; then
  has_new=1
fi
if printf '%s\n' "$state_list" | grep -qx 'random_pet.old_name'; then
  has_old=1
fi

if [ "$has_new" -eq 1 ]; then
  echo "  OK   state contains random_pet.new_name"
else
  echo "  FAIL state does NOT contain random_pet.new_name"
  fail=$((fail+1))
fi

if [ "$has_old" -eq 0 ]; then
  echo "  OK   state does NOT contain random_pet.old_name"
else
  echo "  FAIL state still contains random_pet.old_name (run: terraform state mv random_pet.old_name random_pet.new_name)"
  fail=$((fail+1))
fi

# 3) HCL references random_pet.new_name (and not old_name).
hcl_new=0
hcl_old=0
if grep -Rqs 'random_pet"[[:space:]]*"new_name"' . --include='*.tf'; then
  hcl_new=1
fi
if grep -Rqs 'random_pet"[[:space:]]*"old_name"' . --include='*.tf'; then
  hcl_old=1
fi

if [ "$hcl_new" -eq 1 ]; then
  echo "  OK   HCL declares random_pet \"new_name\""
else
  echo "  FAIL HCL does not declare random_pet \"new_name\""
  fail=$((fail+1))
fi

if [ "$hcl_old" -eq 0 ]; then
  echo "  OK   HCL no longer declares random_pet \"old_name\""
else
  echo "  FAIL HCL still declares random_pet \"old_name\""
  fail=$((fail+1))
fi

# 4) terraform plan must be a no-op.
echo "  ..  running terraform plan -detailed-exitcode (silently)"
terraform plan -detailed-exitcode -input=false -no-color >/tmp/tf-05-01-plan.log 2>&1
plan_code=$?

case "$plan_code" in
  0)
    echo "  OK   terraform plan reports: No changes (no-op)"
    ;;
  2)
    echo "  FAIL terraform plan proposes changes — rename was not clean."
    echo "       See /tmp/tf-05-01-plan.log for details. Expected a no-op."
    fail=$((fail+1))
    ;;
  *)
    echo "  FAIL terraform plan errored (exit $plan_code). See /tmp/tf-05-01-plan.log"
    fail=$((fail+1))
    ;;
esac

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: rename completed cleanly."
exit 0
