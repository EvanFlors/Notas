#!/usr/bin/env bash
# Bootstrap del backend. Dual-mode via MODE={local|live}. Default: local.
# Local: arranca localstack en docker; crea bucket + tabla via awslocal/aws cli.
# Live:  usa credenciales AWS activas; crea bucket + tabla reales.
#
# Note: we deliberately do NOT enable `set -o pipefail` since some pipes use
# `grep -q` early-exit, which can SIGPIPE upstream and give false negatives.
set -eu

MODE="${MODE:-local}"
BUCKET_LOCAL="tf-state-demo"
TABLE_LOCAL="tf-lock-demo"
BUCKET_LIVE="${BUCKET_LIVE:-acme-tf-state-demo-live}"
TABLE_LIVE="${TABLE_LIVE:-acme-tf-lock-demo-live}"
REGION="${REGION:-us-east-1}"
LS_NAME="tf11-localstack"
LS_PORT="${LS_PORT:-4566}"

say() { printf "[bootstrap] %s\n" "$*"; }

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
    echo "SKIP: el daemon de Docker no responde. Arranca Docker Desktop/colima/docker.service."
    exit 0
  fi

  if docker ps --format '{{.Names}}' | grep -qx "$LS_NAME"; then
    say "localstack ya corriendo ($LS_NAME)"
  else
    say "arrancando localstack en :$LS_PORT ..."
    docker run -d --name "$LS_NAME" --rm \
      -p "${LS_PORT}:4566" \
      -e SERVICES=s3,dynamodb \
      -e DEFAULT_REGION="$REGION" \
      localstack/localstack:3 >/dev/null
    # Pequeña espera activa a que levante.
    for i in 1 2 3 4 5 6 7 8 9 10; do
      if curl -fs "http://localhost:${LS_PORT}/_localstack/health" >/dev/null 2>&1; then
        say "localstack listo"
        break
      fi
      sleep 1
      [ "$i" -eq 10 ] && { echo "ERROR: localstack no respondió en 10s"; exit 1; }
    done
  fi

  export AWS_ACCESS_KEY_ID=test
  export AWS_SECRET_ACCESS_KEY=test
  export AWS_DEFAULT_REGION="$REGION"
  AWS_ENDPOINT="http://localhost:${LS_PORT}"
  AWS="aws --endpoint-url=$AWS_ENDPOINT"

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

LISTO (modo local).
Exporta en tu shell antes de 'terraform init':
  export AWS_ACCESS_KEY_ID=test
  export AWS_SECRET_ACCESS_KEY=test
  export AWS_DEFAULT_REGION=$REGION
  export AWS_ENDPOINT_URL_S3=$AWS_ENDPOINT
  export AWS_ENDPOINT_URL_DYNAMODB=$AWS_ENDPOINT

Luego:
  terraform init -backend-config=backend.hcl.local
  terraform apply -auto-approve
EOF

elif [ "$MODE" = "live" ]; then
  if ! command -v aws >/dev/null 2>&1; then
    echo "ERROR: aws CLI no está instalado."
    exit 1
  fi
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "ERROR: credenciales AWS no disponibles. Exporta AWS_PROFILE o AWS_ACCESS_KEY_ID/SECRET."
    exit 1
  fi
  say "cuenta AWS: $(aws sts get-caller-identity --query Account --output text)"
  say "region:     $REGION"
  say "bucket:     $BUCKET_LIVE"
  say "tabla:      $TABLE_LIVE"
  say "COSTO esperado: ~\$0 (dentro de Free Tier para S3+DDB a este volumen)."

  if aws s3api head-bucket --bucket "$BUCKET_LIVE" 2>/dev/null; then
    say "bucket existe"
  else
    say "creando bucket"
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
    say "tabla existe"
  else
    say "creando tabla"
    aws dynamodb create-table \
      --table-name "$TABLE_LIVE" \
      --region "$REGION" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST >/dev/null
  fi

  cat <<EOF

LISTO (modo live).
  terraform init -backend-config=backend.hcl.live
  terraform apply -auto-approve
EOF

else
  echo "ERROR: MODE debe ser 'local' o 'live' (recibido: $MODE)"
  exit 2
fi
