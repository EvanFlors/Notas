#!/usr/bin/env bash
# Structural validation for aws-10-01-fastapi-on-ecs-fargate.
# Checks that task-definition.json is valid, uses Fargate + awsvpc, has roles
# split, has awslogs logging, and that main.tf declares the required ECS
# resources + an ALB target group with target_type=ip.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT apply anything to AWS. Does NOT validate semantic correctness in a
# real account — compare manually with solution/.

set -eu

BASE="${1:-/tmp/aws-10-ecs-fargate}"
JSON="$BASE/task-definition.json"
TF="$BASE/main.tf"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: 'jq' is required but not installed."
  exit 2
fi

# --- task-definition.json ---------------------------------------------------
if [ ! -f "$JSON" ]; then
  echo "FAIL: $JSON does not exist. Copy starter/ first."
  exit 1
fi

if jq empty "$JSON" >/dev/null 2>&1; then
  echo "  OK   task-definition.json is valid JSON"
else
  echo "  FAIL task-definition.json is not valid JSON"
  exit 1
fi

check_jq() {
  local expr="$1"
  local label="$2"
  local val
  val=$(jq -r "$expr" "$JSON" 2>/dev/null || echo "")
  if [ "$val" = "true" ]; then
    echo "  OK   task-definition.json: ${label}"
  else
    echo "  FAIL task-definition.json: ${label} (expr: $expr)"
    fail=$((fail+1))
  fi
}

check_jq '(.family | type == "string") and (.family != "" and .family != "TODO-family")' \
  'family is a non-empty, non-placeholder string'
check_jq '[.requiresCompatibilities[]] | any(. == "FARGATE")' \
  'requiresCompatibilities includes "FARGATE"'
check_jq '.networkMode == "awsvpc"' 'networkMode == "awsvpc"'
check_jq '(.cpu | type == "string") and (.cpu != "TODO") and (.cpu | test("^[0-9]+$"))' \
  'cpu is a numeric string (e.g. "512")'
check_jq '(.memory | type == "string") and (.memory != "TODO") and (.memory | test("^[0-9]+$"))' \
  'memory is a numeric string (e.g. "1024")'
check_jq '(.executionRoleArn | type == "string") and (.executionRoleArn | startswith("arn:aws:iam::")) and (.executionRoleArn | contains("TODO") | not)' \
  'executionRoleArn is an IAM ARN without TODO'
check_jq '(.taskRoleArn | type == "string") and (.taskRoleArn | startswith("arn:aws:iam::")) and (.taskRoleArn | contains("TODO") | not)' \
  'taskRoleArn is an IAM ARN without TODO'
check_jq '.executionRoleArn != .taskRoleArn' \
  'executionRoleArn and taskRoleArn are distinct (critical!)'
check_jq '(.containerDefinitions | type == "array") and (.containerDefinitions | length >= 1)' \
  'containerDefinitions has at least one container'
check_jq '.containerDefinitions[0].essential == true' 'first container has essential=true'
check_jq '(.containerDefinitions[0].name | type == "string") and (.containerDefinitions[0].name != "TODO")' \
  'first container has a non-placeholder name'
check_jq '(.containerDefinitions[0].image | type == "string") and (.containerDefinitions[0].image | contains("TODO") | not)' \
  'first container image is non-placeholder'
check_jq '[.containerDefinitions[0].portMappings[].containerPort] | any(. > 0)' \
  'first container exposes at least one non-zero port'
check_jq '.containerDefinitions[0].logConfiguration.logDriver == "awslogs"' \
  'first container uses logDriver "awslogs"'
check_jq '(.containerDefinitions[0].logConfiguration.options["awslogs-group"] // "") | (. != "" and . != "TODO")' \
  'awslogs-group is set and non-placeholder'
check_jq '(.containerDefinitions[0].logConfiguration.options["awslogs-region"] // "") | (. != "" and . != "TODO")' \
  'awslogs-region is set and non-placeholder'
check_jq '(.containerDefinitions[0].logConfiguration.options["awslogs-stream-prefix"] // "") | (. != "" and . != "TODO")' \
  'awslogs-stream-prefix is set and non-placeholder'

# --- main.tf ---------------------------------------------------------------
if [ ! -f "$TF" ]; then
  echo "FAIL: $TF does not exist."
  exit 1
fi

check_tf() {
  local pattern="$1"
  local label="$2"
  if grep -qE "$pattern" "$TF"; then
    echo "  OK   main.tf: ${label}"
  else
    echo "  FAIL main.tf: ${label} (pattern: $pattern)"
    fail=$((fail+1))
  fi
}

check_tf 'resource +"aws_ecs_cluster"' 'declares aws_ecs_cluster'
check_tf 'resource +"aws_ecs_task_definition"' 'declares aws_ecs_task_definition'
check_tf 'resource +"aws_ecs_service"' 'declares aws_ecs_service'
check_tf 'resource +"aws_lb_target_group"' 'declares aws_lb_target_group'
check_tf 'target_type[[:space:]]*=[[:space:]]*"ip"' \
  'target group uses target_type = "ip" (required for Fargate)'
check_tf 'launch_type[[:space:]]*=[[:space:]]*"FARGATE"' \
  'ecs service uses launch_type = "FARGATE"'
check_tf 'network_mode[[:space:]]*=[[:space:]]*"awsvpc"' \
  'task definition uses network_mode = "awsvpc"'
check_tf 'requires_compatibilities[[:space:]]*=[[:space:]]*\[[^]]*"FARGATE"' \
  'task definition requires_compatibilities includes FARGATE'
check_tf 'execution_role_arn[[:space:]]*=' 'task definition sets execution_role_arn'
check_tf 'task_role_arn[[:space:]]*=' 'task definition sets task_role_arn'
check_tf 'network_configuration' 'service has network_configuration block'
check_tf 'load_balancer[[:space:]]*\{' 'service has load_balancer block'

# TODO markers must be gone from the TF file.
if grep -qE '^//[[:space:]]*TODO [1-9]' "$TF"; then
  echo "  FAIL main.tf still contains TODO markers (TODO 1..4)"
  fail=$((fail+1))
else
  echo "  OK   main.tf has no remaining TODO markers"
fi

# Soft check: run terraform validate if available (does not call AWS). Opt-in via
# RUN_TERRAFORM=1 to avoid downloading the provider on every validator run.
if [ "${RUN_TERRAFORM:-0}" = "1" ] && command -v terraform >/dev/null 2>&1; then
  (
    cd "$BASE"
    if terraform init -backend=false -input=false >/dev/null 2>&1 && \
       terraform validate >/dev/null 2>&1; then
      echo "  OK   terraform init && terraform validate pass locally"
    else
      echo "  WARN terraform validate did not pass (check with 'terraform validate' manually)"
    fi
  )
else
  echo "  INFO 'terraform validate' soft check skipped (set RUN_TERRAFORM=1 to enable; needs network for provider download)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Compare with solution/ to self-grade semantic correctness.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/ para autoevaluarte."
exit 0
