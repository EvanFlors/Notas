#!/usr/bin/env bash
# Reference solution for tf-05-01: build the starter stack, apply, rename
# in HCL + state, and prove the plan is a no-op.
#
# Not meant to be re-run multiple times without cleanup — use /tmp/.
#
# Usage:
#   bash rename.sh [WORKDIR]
# Defaults to /tmp/tf-05-01-rename.

set -euo pipefail

WORK="${1:-/tmp/tf-05-01-rename}"
HERE="$(cd "$(dirname "$0")" && pwd)"
STARTER="$HERE/../starter"

if [ ! -d "$STARTER" ]; then
  echo "FAIL: starter directory not found at $STARTER" >&2
  exit 1
fi

rm -rf "$WORK"
mkdir -p "$WORK"
cp -R "$STARTER/." "$WORK/"
cd "$WORK"

echo "== 1) terraform init + apply (starter) =="
terraform init -input=false -no-color
terraform apply -auto-approve -no-color

echo
echo "== 2) rename in HCL =="
# Replace resource "random_pet" "old_name" with "new_name"
# AND the reference inside local_file.
sed -i.bak \
  -e 's/resource "random_pet" "old_name"/resource "random_pet" "new_name"/' \
  -e 's/random_pet\.old_name\.id/random_pet.new_name.id/' \
  main.tf
rm -f main.tf.bak

echo
echo "== 3) terraform state mv =="
terraform state mv random_pet.old_name random_pet.new_name

echo
echo "== 4) terraform plan (expect: no changes) =="
set +e
terraform plan -detailed-exitcode -no-color
code=$?
set -e

case "$code" in
  0) echo "OK: plan is a no-op." ;;
  2) echo "FAIL: plan has changes." >&2; exit 1 ;;
  *) echo "FAIL: terraform plan errored (exit $code)." >&2; exit 1 ;;
esac
