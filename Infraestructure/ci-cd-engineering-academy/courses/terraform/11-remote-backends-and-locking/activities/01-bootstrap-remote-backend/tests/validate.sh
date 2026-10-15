#!/usr/bin/env bash
# Validate tf-11-01-bootstrap-remote-backend.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `aws ... | grep -q ...`; if grep matches early it can trigger
# SIGPIPE on the upstream command (exit 141), and pipefail would promote that
# to a failure of the whole pipeline — a false negative.

MODE="${MODE:-local}"
WORK="${WORK_DIR:-/tmp/tf-11-01}"
LS_PORT="${LS_PORT:-4566}"
BUCKET="${BUCKET:-tf-state-tf11}"
TABLE="${TABLE:-tf-lock-tf11}"
KEY="${KEY:-tf-11-01/terraform.tfstate}"

passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight ---
if ! command -v aws >/dev/null 2>&1; then
  echo "SKIP: aws CLI no está instalado. Instala awscli v2."
  exit 0
fi

if [ "$MODE" = "local" ]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "SKIP: docker no instalado; MODE=local requiere localstack."
    exit 0
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "SKIP: daemon de Docker no responde."
    exit 0
  fi
  if ! curl -fs "http://localhost:${LS_PORT}/_localstack/health" >/dev/null 2>&1; then
    echo "SKIP: localstack no está en :${LS_PORT}. Corre scripts/bootstrap-backend.sh primero."
    exit 0
  fi
  export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
  export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
  AWS_S3="aws --endpoint-url=http://localhost:${LS_PORT} s3"
  AWS_S3API="aws --endpoint-url=http://localhost:${LS_PORT} s3api"
  AWS_DDB="aws --endpoint-url=http://localhost:${LS_PORT} dynamodb"
elif [ "$MODE" = "live" ]; then
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "SKIP: credenciales AWS no disponibles."
    exit 0
  fi
  AWS_S3="aws s3"
  AWS_S3API="aws s3api"
  AWS_DDB="aws dynamodb"
else
  echo "ERROR: MODE debe ser 'local' o 'live'."
  exit 2
fi

echo "== Validando estado del lab en: $WORK (MODE=$MODE) =="

# --- 1. Workdir existe ---
if [ ! -d "$WORK" ]; then
  bad "WORK dir $WORK no existe"
else
  ok "WORK dir $WORK existe"
fi

# --- 2. Bucket existe ---
if $AWS_S3API head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  ok "bucket $BUCKET existe"

  ver="$($AWS_S3API get-bucket-versioning --bucket "$BUCKET" --query Status --output text 2>/dev/null)"
  if [ "$ver" = "Enabled" ]; then
    ok "bucket $BUCKET versioning=Enabled"
  else
    bad "bucket $BUCKET versioning='$ver' (esperado Enabled)"
  fi
else
  bad "bucket $BUCKET no existe"
fi

# --- 3. Tabla existe ---
if $AWS_DDB describe-table --table-name "$TABLE" >/dev/null 2>&1; then
  ok "tabla $TABLE existe"
  pk="$($AWS_DDB describe-table --table-name "$TABLE" \
        --query 'Table.KeySchema[0].AttributeName' --output text 2>/dev/null)"
  if [ "$pk" = "LockID" ]; then
    ok "tabla $TABLE PK=LockID"
  else
    bad "tabla $TABLE PK='$pk' (esperado LockID)"
  fi
else
  bad "tabla $TABLE no existe"
fi

# --- 4. State remoto subido ---
if $AWS_S3API head-object --bucket "$BUCKET" --key "$KEY" >/dev/null 2>&1; then
  ok "objeto s3://$BUCKET/$KEY existe"
else
  bad "objeto s3://$BUCKET/$KEY no existe (¿corriste terraform init -migrate-state?)"
fi

# --- 5. .terraform/terraform.tfstate (metadata) apunta a s3 ---
meta="$WORK/.terraform/terraform.tfstate"
if [ -f "$meta" ]; then
  if grep -q '"type": "s3"' "$meta"; then
    ok ".terraform/terraform.tfstate apunta a backend s3"
  else
    bad ".terraform/terraform.tfstate no apunta a backend s3"
  fi
else
  bad "falta $meta (¿corriste terraform init?)"
fi

# --- 6. No queda terraform.tfstate local con recursos reales ---
#     (puede quedar un .backup o un .tfstate vacío post-migrate; aceptamos ambos).
local_state="$WORK/terraform.tfstate"
if [ -f "$local_state" ]; then
  resources_count="$(grep -c '"type"' "$local_state" 2>/dev/null || echo 0)"
  if [ "$resources_count" -gt 0 ]; then
    # No es FAIL duro — aviso: idealmente debería estar vacío o borrado.
    report+="  WARN quedó terraform.tfstate local con $resources_count líneas 'type' (puede borrarse)\n"
  else
    ok "terraform.tfstate local vacío (ok)"
  fi
else
  ok "no quedó terraform.tfstate local"
fi

echo -e "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
