#!/usr/bin/env bash
# Example 03 — Terraform validate + plan of an App Runner service.
# No real AWS calls succeed; we only need `validate` to pass.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

cd "$(dirname "$0")"

if ! command -v terraform >/dev/null 2>&1; then
  echo "SKIP: terraform not available"
  exit 0
fi

SCRATCH="/tmp/aws-10-ex03"
rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"
cp main.tf "$SCRATCH/"

cleanup() {
  rm -rf "$SCRATCH"
}
trap cleanup EXIT

cd "$SCRATCH"

echo "== terraform init -backend=false"
terraform init -backend=false -input=false >/dev/null

echo "== terraform validate"
terraform validate

echo "== terraform plan (expected to fail at AWS API calls)"
terraform plan -input=false -refresh=false -no-color >/dev/null 2>&1 || true

ok=1

echo
echo "== structural checks on main.tf"
for pattern in \
  'resource "aws_apprunner_service"' \
  'source_configuration' \
  'image_repository' \
  'image_repository_type[[:space:]]*=[[:space:]]*"ECR"' \
  'authentication_configuration' \
  'instance_configuration' \
  'health_check_configuration' \
  'instance_role_arn' \
  'access_role_arn'
do
  if grep -qE "$pattern" main.tf; then
    echo "  OK   contains $pattern"
  else
    echo "  FAIL missing $pattern"
    ok=0
  fi
done

if grep -qE '000000000000' main.tf; then
  echo "  OK   uses placeholder account id (000000000000), no real id"
else
  echo "  FAIL expected placeholder account id 000000000000"
  ok=0
fi

echo
if [ "$ok" -eq 1 ]; then
  echo "OK: example 03 — App Runner Terraform validates and HCL has expected shape"
  exit 0
else
  echo "FAIL: example 03"
  exit 1
fi
