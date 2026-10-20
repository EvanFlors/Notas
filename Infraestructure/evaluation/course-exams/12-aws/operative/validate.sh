#!/usr/bin/env bash
# Validador del ejercicio operativo del examen AWS.
# No consume AWS real. Usa `terraform plan` offline y, si está disponible, LocalStack.
# Marca SKIP (no FAIL) cuando una dependencia opcional no está presente.

set -uo pipefail

SUBMISSION_DIR="${1:-submission}"
PASS=0
FAIL=0
SKIP=0

pass() { echo "PASS  $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL  $1"; FAIL=$((FAIL+1)); }
skip() { echo "SKIP  $1 ($2)"; SKIP=$((SKIP+1)); }

need() { command -v "$1" >/dev/null 2>&1; }

if ! need terraform; then
  echo "terraform no está instalado; no se puede validar nada." >&2
  exit 2
fi
if ! need jq; then
  echo "jq no está instalado; requerido para los asserts." >&2
  exit 2
fi

LOCALSTACK_UP=0
if need curl && curl -sf http://localhost:4566/_localstack/health >/dev/null 2>&1; then
  LOCALSTACK_UP=1
fi

############################################
# OP-task-1 — S3 seguro
############################################
echo "=== OP-task-1 — S3 seguro ==="
T1="$SUBMISSION_DIR/task-1-s3"
if [[ -d "$T1" ]]; then
  pushd "$T1" >/dev/null
  terraform init -backend=false -input=false >/dev/null 2>&1 \
    && pass "task1.init" || fail "task1.init"
  terraform validate >/dev/null 2>&1 \
    && pass "task1.validate" || fail "task1.validate"
  terraform plan -input=false \
    -var='env=dev' \
    -var='kms_admin_role_arn=arn:aws:iam::123456789012:role/kms-admin' \
    -out=tfplan.binary >/dev/null 2>&1 \
    && pass "task1.plan" || fail "task1.plan"
  if [[ -f tfplan.binary ]]; then
    terraform show -json tfplan.binary > plan.json 2>/dev/null
    jq -e '.resource_changes[] | select(.type=="aws_s3_bucket_public_access_block") | .change.after | select(.block_public_acls==true and .block_public_policy==true and .ignore_public_acls==true and .restrict_public_buckets==true)' plan.json >/dev/null \
      && pass "task1.bpa" || fail "task1.bpa"
    jq -e '.resource_changes[] | select(.type=="aws_s3_bucket_versioning") | .change.after.versioning_configuration[0].status | select(.=="Enabled")' plan.json >/dev/null \
      && pass "task1.versioning" || fail "task1.versioning"
    jq -e '.resource_changes[] | select(.type=="aws_kms_key")' plan.json >/dev/null \
      && pass "task1.cmk" || fail "task1.cmk"
    jq -r '.resource_changes[] | select(.type=="aws_s3_bucket_policy") | .change.after.policy' plan.json 2>/dev/null | grep -q 'aws:SecureTransport' \
      && pass "task1.secureTransport" || fail "task1.secureTransport"
    jq -r '.resource_changes[] | select(.type=="aws_s3_bucket_policy") | .change.after.policy' plan.json 2>/dev/null | grep -q 'aws:PrincipalOrgID' \
      && pass "task1.orgIdCondition" || fail "task1.orgIdCondition"
    jq -e '.resource_changes[] | select(.type=="aws_s3_bucket_lifecycle_configuration")' plan.json >/dev/null \
      && pass "task1.lifecycle" || fail "task1.lifecycle"
  fi
  if (( LOCALSTACK_UP == 1 )); then
    pass "task1.localstack.detected"
  else
    skip "task1.localstack.apply" "LocalStack no está en localhost:4566"
  fi
  popd >/dev/null
else
  fail "task1.exists"
fi

############################################
# OP-task-2 — OIDC audit
############################################
echo "=== OP-task-2 — OIDC pipeline audit ==="
T2="$SUBMISSION_DIR/task-2-oidc-audit"
if [[ -d "$T2/after" ]]; then
  AFTER_WF="$T2/after/pipeline.yml"
  AFTER_TRUST="$T2/after/trust-policy.json"
  if [[ -f "$AFTER_WF" ]]; then
    if need actionlint; then
      actionlint "$AFTER_WF" >/dev/null 2>&1 \
        && pass "task2.actionlint" || fail "task2.actionlint"
    else
      skip "task2.actionlint" "actionlint no está instalado"
    fi
    if grep -qE 'aws-(access-key-id|secret-access-key)' "$AFTER_WF"; then
      fail "task2.noLongLivedKeys"
    else
      pass "task2.noLongLivedKeys"
    fi
    grep -qE 'id-token:\s*write' "$AFTER_WF" \
      && pass "task2.idTokenPermission" || fail "task2.idTokenPermission"
  else
    fail "task2.pipeline.exists"
  fi
  if [[ -f "$AFTER_TRUST" ]]; then
    jq -e '.Statement[] | .Condition.StringEquals["token.actions.githubusercontent.com:sub"]' "$AFTER_TRUST" >/dev/null 2>&1 \
      && pass "task2.subPinned" || fail "task2.subPinned"
    jq -r '.Statement[] | .Condition.StringEquals["token.actions.githubusercontent.com:sub"] // empty' "$AFTER_TRUST" 2>/dev/null \
      | grep -qE 'repo:[^:]+:(environment|ref|pull_request)' \
      && pass "task2.subFormat" || fail "task2.subFormat"
  else
    fail "task2.trustPolicy.exists"
  fi
  LEAKED=$(grep -rhoE '\b[0-9]{12}\b' "$T2/after" 2>/dev/null | grep -vE '^(123456789012|210987654321)$' | head -1)
  if [[ -z "$LEAKED" ]]; then
    pass "task2.noRealAccountId"
  else
    fail "task2.noRealAccountId (filtrado: $LEAKED)"
  fi
  [[ -f "$T2/AUDIT.md" ]] \
    && pass "task2.auditDoc" || fail "task2.auditDoc"
else
  fail "task2.exists"
fi

############################################
# OP-task-3 — Observability
############################################
echo "=== OP-task-3 — CloudWatch retention + alarms ==="
T3="$SUBMISSION_DIR/task-3-observability"
if [[ -d "$T3" ]]; then
  pushd "$T3" >/dev/null
  terraform init -backend=false -input=false >/dev/null 2>&1 \
    && pass "task3.init" || fail "task3.init"
  terraform validate >/dev/null 2>&1 \
    && pass "task3.validate" || fail "task3.validate"
  terraform plan -input=false -out=tfplan.binary >/dev/null 2>&1 \
    && pass "task3.plan" || fail "task3.plan"
  if [[ -f tfplan.binary ]]; then
    terraform show -json tfplan.binary > plan.json 2>/dev/null
    jq -e '[.resource_changes[] | select(.type=="aws_cloudwatch_log_group")] | length >= 3' plan.json >/dev/null \
      && pass "task3.logGroups" || fail "task3.logGroups"
    jq -e '.resource_changes[] | select(.type=="aws_cloudwatch_composite_alarm")' plan.json >/dev/null \
      && pass "task3.composite" || fail "task3.composite"
    jq -e '.resource_changes[] | select(.type=="aws_cloudwatch_metric_alarm" and ((.change.after.metric_query // []) | length > 0))' plan.json >/dev/null \
      && pass "task3.anomaly" || fail "task3.anomaly"
    jq -e '[.resource_changes[] | select(.type=="aws_cloudwatch_log_group") | .change.after.kms_key_id] | all(. != null)' plan.json >/dev/null \
      && pass "task3.logEncryption" || fail "task3.logEncryption"
  fi
  [[ -f retention-policy.md ]] \
    && pass "task3.retentionDoc" || fail "task3.retentionDoc"
  popd >/dev/null
else
  fail "task3.exists"
fi

echo
echo "============================================="
echo "Resumen: PASS=$PASS  FAIL=$FAIL  SKIP=$SKIP"
echo "============================================="
exit $(( FAIL > 0 ? 1 : 0 ))
