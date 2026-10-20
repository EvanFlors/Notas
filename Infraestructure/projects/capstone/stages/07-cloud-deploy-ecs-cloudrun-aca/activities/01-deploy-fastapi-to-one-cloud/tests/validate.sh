#!/usr/bin/env bash
# Structural validation for cap-07-01-deploy-fastapi-to-one-cloud.
#
# Reads choice.txt to decide which cloud module to inspect, then checks that
# the four TODO blocks have been resolved AND that the module hits the key
# requirements (image by digest, runtime identity declared, secret from secret
# manager injected to the container).
#
# Note: we deliberately do NOT enable `set -o pipefail` because grep-based
# checks can produce SIGPIPE (exit 141) when grep exits early. pipefail would
# spuriously mark those as failures.
#
# This script does NOT call any cloud API. Semantic correctness in a real
# project is NOT verified here — compare manually with solution/.

set -eu

BASE="${1:-/tmp/cap-07-01}"
CHOICE_FILE="$BASE/choice.txt"
fail=0

echo "== Structural validation for $BASE =="

# ---------- choice.txt ------------------------------------------------------
if [ ! -f "$CHOICE_FILE" ]; then
  echo "FAIL: $CHOICE_FILE does not exist. Copy starter/ first."
  exit 1
fi

choice=$(head -n1 "$CHOICE_FILE" | tr -d '[:space:]')
case "$choice" in
  aws)   TF_DIR="$BASE/terraform/aws/ecs-fargate" ;;
  gcp)   TF_DIR="$BASE/terraform/gcp/cloud-run" ;;
  azure) TF_DIR="$BASE/terraform/azure/container-apps" ;;
  *)
    echo "FAIL: choice.txt must contain exactly one of: aws, gcp, azure (got: '$choice')"
    exit 1
    ;;
esac
echo "  OK   choice.txt selects '$choice'"

TF="$TF_DIR/main.tf"
if [ ! -f "$TF" ]; then
  echo "FAIL: $TF does not exist."
  exit 1
fi

# ---------- Shared helper ---------------------------------------------------
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

check_tf_absent() {
  local pattern="$1"
  local label="$2"
  if grep -qE "$pattern" "$TF"; then
    echo "  FAIL main.tf: ${label} (unexpected pattern still present: $pattern)"
    fail=$((fail+1))
  else
    echo "  OK   main.tf: ${label}"
  fi
}

# ---------- Shared: TODO markers gone, image by digest ----------------------
if grep -qE '^[[:space:]]*//[[:space:]]*TODO [1-9]' "$TF"; then
  echo "  FAIL main.tf still contains '// TODO N' markers"
  fail=$((fail+1))
else
  echo "  OK   main.tf has no remaining '// TODO N' markers"
fi

check_tf_absent 'image_ref[[:space:]]*=[[:space:]]*null' 'image_ref is no longer null (TODO 1 resolved)'
check_tf 'var\.image_digest' 'image reference uses var.image_digest'
# The digest default in variables.tf must contain @sha256:
if grep -q '@sha256:' "$TF_DIR/variables.tf"; then
  echo "  OK   variables.tf: image_digest default pins by @sha256:"
else
  echo "  FAIL variables.tf: image_digest default does not contain '@sha256:'"
  fail=$((fail+1))
fi

# ---------- Per-cloud checks ------------------------------------------------
case "$choice" in
  aws)
    check_tf 'resource +"aws_iam_role" +"task"' 'TODO 2: aws_iam_role.task declared'
    check_tf 'resource +"aws_secretsmanager_secret" +"db_dsn"' 'TODO 3: db_dsn secret declared'
    check_tf 'resource +"aws_secretsmanager_secret_version"' 'TODO 3: secret_version declared'
    check_tf 'resource +"aws_iam_role_policy"' 'TODO 3: inline policy on execution role'
    check_tf 'secretsmanager:GetSecretValue' 'TODO 3: policy grants GetSecretValue'
    check_tf 'execution_role_arn[[:space:]]*=[[:space:]]*aws_iam_role\.execution\.arn' \
      'TODO 4: execution_role_arn wired'
    check_tf 'task_role_arn[[:space:]]*=[[:space:]]*aws_iam_role\.task\.arn' \
      'TODO 4: task_role_arn wired to task role (NOT execution)'
    check_tf 'APP_DB_DSN' 'TODO 4: APP_DB_DSN name present'
    check_tf 'valueFrom' 'TODO 4: secret injected via valueFrom (not plaintext env)'
    check_tf_absent '"environment"[[:space:]]*=.*APP_DB_DSN' \
      'TODO 4: APP_DB_DSN is NOT set via plaintext environment'
    check_tf 'target_type[[:space:]]*=[[:space:]]*"ip"' 'ALB target_type = "ip" (Fargate requirement)'
    check_tf 'launch_type[[:space:]]*=[[:space:]]*"FARGATE"' 'service uses launch_type = "FARGATE"'
    check_tf 'network_mode[[:space:]]*=[[:space:]]*"awsvpc"' 'task definition uses awsvpc'
    check_tf 'publicly_accessible[[:space:]]*=[[:space:]]*false' 'RDS publicly_accessible = false'
    check_tf 'capstone' 'default_tags include capstone (for cleanup script)'
    ;;

  gcp)
    check_tf 'resource +"google_service_account" +"runtime"' 'TODO 2: runtime SA declared'
    check_tf 'resource +"google_secret_manager_secret" +"db_dsn"' 'TODO 3: db_dsn secret declared'
    check_tf 'resource +"google_secret_manager_secret_version"' 'TODO 3: secret_version declared'
    check_tf 'resource +"google_secret_manager_secret_iam_member"' 'TODO 3: IAM binding to runtime SA'
    check_tf 'roles/secretmanager\.secretAccessor' 'TODO 3: role is secretAccessor'
    check_tf 'service_account[[:space:]]*=[[:space:]]*google_service_account\.runtime\.email' \
      'TODO 4: template.service_account wired to runtime SA'
    check_tf 'APP_DB_DSN' 'TODO 4: APP_DB_DSN env name present'
    check_tf 'secret_key_ref' 'TODO 4: env uses secret_key_ref (not plaintext value)'
    check_tf 'ipv4_enabled[[:space:]]*=[[:space:]]*false' 'Cloud SQL has public IP disabled'
    check_tf 'capstone' 'labels include capstone (for cleanup script)'
    ;;

  azure)
    check_tf 'resource +"azurerm_user_assigned_identity" +"runtime"' 'TODO 2: user-assigned identity declared'
    check_tf 'resource +"azurerm_key_vault" +"kv"' 'TODO 3: Key Vault declared'
    check_tf 'resource +"azurerm_key_vault_secret" +"db_dsn"' 'TODO 3: KV secret declared'
    check_tf 'Key Vault Secrets User' 'TODO 3: runtime identity gets "Key Vault Secrets User"'
    check_tf 'identity_ids[[:space:]]*=[[:space:]]*\[azurerm_user_assigned_identity\.runtime\.id\]' \
      'TODO 4: Container App attaches user-assigned identity'
    check_tf 'type[[:space:]]*=[[:space:]]*"UserAssigned"' 'TODO 4: identity.type = "UserAssigned"'
    check_tf 'key_vault_secret_id' 'TODO 4: Container App secret references Key Vault'
    check_tf 'APP_DB_DSN' 'TODO 4: APP_DB_DSN env name present'
    check_tf 'secret_name[[:space:]]*=[[:space:]]*"db-dsn"' 'TODO 4: env.secret_name wires db-dsn'
    check_tf 'public_network_access_enabled[[:space:]]*=[[:space:]]*false' 'Postgres public access disabled'
    check_tf 'capstone' 'tags include capstone (for cleanup script)'
    ;;
esac

# ---------- Optional soft check: terraform validate -------------------------
if [ "${RUN_TERRAFORM:-0}" = "1" ] && command -v terraform >/dev/null 2>&1; then
  (
    cd "$TF_DIR"
    if terraform init -backend=false -input=false >/dev/null 2>&1 && \
       terraform validate >/dev/null 2>&1; then
      echo "  OK   terraform init && terraform validate pass locally"
    else
      echo "  WARN terraform validate did not pass (run manually to see errors)"
    fi
  )
else
  echo "  INFO 'terraform validate' soft check skipped (set RUN_TERRAFORM=1 to enable)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s)."
  echo "        (Compare with solution/ to self-grade semantic correctness.)"
  exit 1
fi
echo "RESULT: 0 issue(s). Modulo del cloud elegido pasa validacion estructural."
echo "        Compara con solution/ para autoevaluacion semantica."
exit 0
