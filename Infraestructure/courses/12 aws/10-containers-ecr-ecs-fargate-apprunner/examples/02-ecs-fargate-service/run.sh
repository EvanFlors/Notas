#!/usr/bin/env bash
# Example 02 — Terraform validate + plan of an ECS Fargate service.
# Does NOT touch AWS: fake creds + skip_* flags let `validate` run and
# `plan` reach API calls that fail cleanly without real resources.
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
if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq not available"
  exit 0
fi

SCRATCH="/tmp/aws-10-ex02"
rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"
cp main.tf task-definition.json "$SCRATCH/"

cleanup() {
  rm -rf "$SCRATCH"
}
trap cleanup EXIT

cd "$SCRATCH"

echo "== terraform init -backend=false"
terraform init -backend=false -input=false >/dev/null

echo "== terraform validate"
terraform validate

echo "== terraform plan (expected to fail at AWS API calls — we only need graph construction)"
# We tolerate failure here; the point is that validate passed.
terraform plan -input=false -refresh=false -no-color >/dev/null 2>&1 || true

echo
echo "== structural checks on task-definition.json"
TDEF="task-definition.json"
ok=1

check() {
  local msg="$1"
  local expr="$2"
  if [ "$(jq -r "$expr" "$TDEF")" = "true" ]; then
    echo "  OK   $msg"
  else
    echo "  FAIL $msg"
    ok=0
  fi
}

check "networkMode == awsvpc"               '.networkMode == "awsvpc"'
check "requiresCompatibilities contains FARGATE" '(.requiresCompatibilities // []) | index("FARGATE") != null'
check "executionRoleArn set"                '(.executionRoleArn // "") | length > 0'
check "taskRoleArn set and distinct from exec" '(.taskRoleArn // "") as $t | (.executionRoleArn // "") as $e | ($t | length > 0) and ($t != $e)'
check "cpu is a valid Fargate size"         '[.cpu] | inside(["256","512","1024","2048","4096","8192","16384"])'
check "memory is set"                       '(.memory // "") | length > 0'
check "at least 1 container"                '(.containerDefinitions | length) >= 1'
check "container has portMappings"          '(.containerDefinitions[0].portMappings | length) >= 1'
check "container has logConfiguration awslogs" '.containerDefinitions[0].logConfiguration.logDriver == "awslogs"'
check "no real account id (uses 000000000000 placeholder)" '(.executionRoleArn // "") | contains("000000000000")'

echo
if [ "$ok" -eq 1 ]; then
  echo "OK: example 02 — Terraform validates and task-definition.json is structurally sound"
  exit 0
else
  echo "FAIL: example 02 — structural problems in task-definition.json"
  exit 1
fi
