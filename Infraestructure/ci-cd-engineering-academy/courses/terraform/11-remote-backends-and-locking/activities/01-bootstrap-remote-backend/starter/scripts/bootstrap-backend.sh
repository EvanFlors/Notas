#!/usr/bin/env bash
# Bootstrap de bucket S3 + tabla DynamoDB para el backend remoto de este lab.
# Dual-mode: MODE=local (localstack) | MODE=live (AWS real).
#
# Note: we deliberately do NOT enable `set -o pipefail` because some pipes use
# `grep -q` early-exit which can SIGPIPE upstream and give false negatives.
set -eu

MODE="${MODE:-local}"
REGION="${REGION:-us-east-1}"
BUCKET_LOCAL="tf-state-tf11"
TABLE_LOCAL="tf-lock-tf11"
BUCKET_LIVE="${BUCKET_LIVE:-tf-state-tf11-$(whoami)-$RANDOM}"
TABLE_LIVE="${TABLE_LIVE:-tf-lock-tf11-$(whoami)}"
LS_NAME="tf11-localstack"
LS_PORT="${LS_PORT:-4566}"

say() { printf "[bootstrap-backend] %s\n" "$*"; }

if [ "$MODE" = "local" ]; then
  if ! command -v docker >/dev/null 2>&1; then
    cat <<EOF
SKIP: docker no está instalado; no puedo arrancar localstack.
Opciones:
  - Instala Docker: https://docs.docker.com/engine/install/
  - Usa MODE=live con credenciales AWS reales.
EOF
    exit 0
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "SKIP: el daemon de Docker no responde."
    exit 0
  fi

  if docker ps --format '{{.Names}}' | grep -qx "$LS_NAME"; then
    say "localstack ya corre ($LS_NAME)"
  else
    say "arrancando localstack en :$LS_PORT"
    docker run -d --name "$LS_NAME" --rm \
      -p "${LS_PORT}:4566" \
      -e SERVICES=s3,dynamodb \
      -e DEFAULT_REGION="$REGION" \
      localstack/localstack:3 >/dev/null
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
      if curl -fs "http://localhost:${LS_PORT}/_localstack/health" >/dev/null 2>&1; then
        say "localstack arriba"
        break
      fi
      sleep 1
      [ "$i" -eq 15 ] && { echo "ERROR: localstack no respondió"; exit 1; }
    done
  fi

  export AWS_ACCESS_KEY_ID=test
  export AWS_SECRET_ACCESS_KEY=test
  export AWS_DEFAULT_REGION="$REGION"
  AWS="aws --endpoint-url=http://localhost:${LS_PORT}"

  if $AWS s3 ls "s3://$BUCKET_LOCAL" >/dev/null 2>&1; then
    say "bucket $BUCKET_LOCAL ya existe"
  else
    say "creando bucket $BUCKET_LOCAL"
    $AWS s3 mb "s3://$BUCKET_LOCAL" >/dev/null
    $AWS s3api put-bucket-versioning --bucket "$BUCKET_LOCAL" \
      --versioning-configuration Status=Enabled >/dev/null
  fi

  if $AWS dynamodb describe-table --table-name "$TABLE_LOCAL" >/dev/null 2>&1; then
    say "tabla $TABLE_LOCAL ya existe"
  else
    say "creando tabla $TABLE_LOCAL"
    $AWS dynamodb create-table \
      --table-name "$TABLE_LOCAL" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST >/dev/null
  fi

  cat <<EOF

LISTO (local). Exporta en tu shell:
  export AWS_ACCESS_KEY_ID=test
  export AWS_SECRET_ACCESS_KEY=test
  export AWS_DEFAULT_REGION=$REGION
  export AWS_ENDPOINT_URL_S3=http://localhost:${LS_PORT}
  export AWS_ENDPOINT_URL_DYNAMODB=http://localhost:${LS_PORT}

Luego, en tu stack:
  terraform init -backend-config=backend.hcl -migrate-state
EOF

elif [ "$MODE" = "live" ]; then
  if ! command -v aws >/dev/null 2>&1; then
    echo "ERROR: aws CLI no está instalado."
    exit 1
  fi
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "ERROR: credenciales AWS no disponibles."
    exit 1
  fi
  say "cuenta: $(aws sts get-caller-identity --query Account --output text)"
  say "region: $REGION   bucket: $BUCKET_LIVE   tabla: $TABLE_LIVE"
  say "COSTO esperado: ~\$0 (Free Tier)."

  if aws s3api head-bucket --bucket "$BUCKET_LIVE" 2>/dev/null; then
    say "bucket ya existe"
  else
    say "creando bucket $BUCKET_LIVE"
    if [ "$REGION" = "us-east-1" ]; then
      aws s3api create-bucket --bucket "$BUCKET_LIVE" --region "$REGION"
    else
      aws s3api create-bucket --bucket "$BUCKET_LIVE" --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
    fi
    aws s3api put-bucket-versioning --bucket "$BUCKET_LIVE" \
      --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption --bucket "$BUCKET_LIVE" \
      --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    aws s3api put-public-access-block --bucket "$BUCKET_LIVE" \
      --public-access-block-configuration \
      'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
  fi
  if aws dynamodb describe-table --table-name "$TABLE_LIVE" --region "$REGION" >/dev/null 2>&1; then
    say "tabla ya existe"
  else
    say "creando tabla $TABLE_LIVE"
    aws dynamodb create-table \
      --table-name "$TABLE_LIVE" \
      --region "$REGION" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST >/dev/null
  fi

  cat <<EOF

LISTO (live). Edita backend.hcl con:
  bucket         = "$BUCKET_LIVE"
  dynamodb_table = "$TABLE_LIVE"
Luego:
  terraform init -backend-config=backend.hcl -migrate-state
EOF
else
  echo "ERROR: MODE debe ser 'local' o 'live' (recibido: $MODE)"
  exit 2
fi
