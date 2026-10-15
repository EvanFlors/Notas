#!/usr/bin/env bash
# Smoke test: Terraform <-> OpenTofu interoperability on a trivial stack.
#
# NOTE: we deliberately do NOT `set -o pipefail` here because several checks pipe
# into `grep -q`, which closes stdin early (SIGPIPE) and would be reported as a
# producer-side failure under pipefail. We check exit codes explicitly instead.
set -eu

STACK_DIR="${STACK_DIR:-$(cd "$(dirname "$0")/stack" && pwd)}"
WORK_DIR="${WORK_DIR:-/tmp/tf-tofu-smoke}"

pass=0
fail=0
ok()  { echo "  OK   -- $1"; pass=$((pass+1)); }
bad() { echo "  FAIL -- $1"; fail=$((fail+1)); }

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp -R "$STACK_DIR"/. "$WORK_DIR/"
cd "$WORK_DIR"

echo "== [1/5] versions =="
if ! command -v terraform >/dev/null 2>&1; then
  echo "SKIP: terraform not installed. Install via: https://developer.hashicorp.com/terraform/install"
  exit 0
fi
if ! command -v tofu >/dev/null 2>&1; then
  echo "SKIP: tofu not installed. Install via: https://opentofu.org/docs/intro/install/"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq not installed. Install via your package manager."
  exit 0
fi
tf_v="$(terraform version -json | jq -r '.terraform_version')"
to_v="$(tofu version -json 2>/dev/null | jq -r '.terraform_version // "unknown"')"
ok "terraform $tf_v / tofu $to_v"

echo "== [2/5] lockfile compatibility =="
terraform init -input=false -no-color >/dev/null
if [ -f .terraform.lock.hcl ]; then
  ok "terraform init produced .terraform.lock.hcl"
else
  bad ".terraform.lock.hcl not produced by terraform init"
fi
rm -rf .terraform
# NOTE: since ~2024 lockfiles are NOT cross-tool because terraform tracks
# registry.terraform.io and tofu tracks registry.opentofu.org. We record the
# outcome but don't fail on it — the state-level compatibility is the point.
set +e
tofu init -input=false -lockfile=readonly -no-color >/dev/null 2>&1
lock_rc=$?
set -e
if [ "$lock_rc" -eq 0 ]; then
  ok "tofu init accepted terraform's lockfile (readonly)"
else
  echo "  NOTE -- tofu init -lockfile=readonly rc=$lock_rc (expected: registry URL divergence)"
fi

echo "== [3/5] plan equivalence =="
rm -rf .terraform
terraform init -input=false -no-color >/dev/null
terraform plan -input=false -no-color -out=t.plan >/dev/null
terraform show -json t.plan > t.json

rm -rf .terraform .terraform.lock.hcl
tofu init -input=false -no-color >/dev/null
tofu plan -input=false -no-color -out=o.plan >/dev/null
tofu show -json o.plan > o.json

# Compare the planned resource_changes structure (addresses + actions).
t_changes="$(jq -S '[.resource_changes[]? | {address, actions: .change.actions}]' t.json)"
o_changes="$(jq -S '[.resource_changes[]? | {address, actions: .change.actions}]' o.json)"
if [ "$t_changes" = "$o_changes" ]; then
  ok "terraform and tofu produced equivalent plans ($(echo "$t_changes" | jq 'length') resources)"
else
  bad "plan diverges between terraform and tofu"
  echo "---- terraform ----"
  echo "$t_changes"
  echo "---- tofu ----"
  echo "$o_changes"
fi

echo "== [4/5] state tf -> tofu =="
rm -rf .terraform .terraform.lock.hcl
terraform init -input=false -no-color >/dev/null
terraform apply -input=false -auto-approve t.plan >/dev/null
# tofu reads the state terraform just wrote. We re-init with tofu to get its
# own provider lockfile (see step 2 note).
rm -rf .terraform .terraform.lock.hcl
tofu init -input=false -no-color >/dev/null
set +e
tofu plan -input=false -no-color -detailed-exitcode >/dev/null
ec=$?
set -e
if [ "$ec" -eq 0 ]; then
  ok "tofu plan on terraform's state: no changes"
else
  bad "tofu plan on terraform's state reports changes (exit=$ec)"
fi

echo "== [5/5] state tofu -> tf =="
# tofu apply (should be a no-op, but we exercise the write path)
tofu apply -input=false -auto-approve >/dev/null
rm -rf .terraform .terraform.lock.hcl
terraform init -input=false -no-color >/dev/null
set +e
terraform plan -input=false -no-color -detailed-exitcode >/dev/null
ec=$?
set -e
if [ "$ec" -eq 0 ]; then
  ok "terraform plan on tofu's state: no changes"
else
  bad "terraform plan on tofu's state reports changes (exit=$ec)"
fi

# Clean up resources before trap (local_file leaves a file in WORK_DIR; destroy via tofu)
tofu destroy -input=false -auto-approve >/dev/null 2>&1 || true

echo
echo "SMOKE TEST: $pass OK / $fail FAIL"
[ "$fail" -eq 0 ] && echo "RESULT: PASS" && exit 0
echo "RESULT: FAIL"
exit 1
