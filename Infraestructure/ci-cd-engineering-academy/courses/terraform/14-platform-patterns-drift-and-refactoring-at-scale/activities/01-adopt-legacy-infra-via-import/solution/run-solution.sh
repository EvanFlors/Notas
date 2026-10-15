#!/usr/bin/env bash
# Reference run: executes the full solution end-to-end from scratch.
# Requires terraform >= 1.5 in PATH.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACTIVITY_DIR="$(cd "$HERE/.." && pwd)"

bash "$ACTIVITY_DIR/starter/bootstrap.sh"

WORKDIR="/tmp/tf14-act01"
cp "$HERE/imports.tf" "$WORKDIR/imports.tf"
cp "$HERE/adopted.tf" "$WORKDIR/adopted.tf"

cd "$WORKDIR"
terraform init -input=false
terraform apply -auto-approve
echo
echo "== plan after apply (expect: No changes) =="
terraform plan -no-color
echo
echo "== state list =="
terraform state list
