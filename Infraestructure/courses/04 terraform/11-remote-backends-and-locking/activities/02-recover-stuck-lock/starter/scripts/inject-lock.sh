#!/usr/bin/env bash
# Inyecta una fila en la tabla DDB para simular un lock colgado.
# Note: NO pipefail — grep -q early-exit puede SIGPIPE upstream (falso negativo).
set -eu

MODE="${MODE:-local}"
TABLE="${TABLE:-tf-lock-tf11}"
BUCKET="${BUCKET:-tf-state-tf11}"
KEY="${KEY:-tf-11-02/terraform.tfstate}"
LS_PORT="${LS_PORT:-4566}"

LOCK_ID="${BUCKET}/${KEY}-md5"
LOCK_INFO_ID="${LOCK_INFO_ID:-f3a1c9e2-aaaa-bbbb-cccc-ddddeeeeffff}"
WHO="${WHO:-alice@laptop}"
CREATED="${CREATED:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

TMP_ITEM="$(mktemp)"
trap 'rm -f "$TMP_ITEM"' EXIT

cat >"$TMP_ITEM" <<EOF
{
  "LockID": {"S": "${LOCK_ID}"},
  "Info":   {"S": "{\"ID\":\"${LOCK_INFO_ID}\",\"Operation\":\"OperationTypeApply\",\"Who\":\"${WHO}\",\"Version\":\"1.6.4\",\"Created\":\"${CREATED}\",\"Path\":\"${BUCKET}/${KEY}\"}"}
}
EOF

if [ "$MODE" = "local" ]; then
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "SKIP: docker/daemon ausente."
    exit 0
  fi
  if ! curl -fs "http://localhost:${LS_PORT}/_localstack/health" >/dev/null 2>&1; then
    echo "SKIP: localstack no está en :${LS_PORT}. Arranca con la actividad 01."
    exit 0
  fi
  export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
  export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
  AWS_DDB="aws --endpoint-url=http://localhost:${LS_PORT} dynamodb"
else
  AWS_DDB="aws dynamodb"
fi

echo "[inject-lock] insertando LockID='${LOCK_ID}' Who='${WHO}'"
$AWS_DDB put-item --table-name "$TABLE" --item "file://$TMP_ITEM" >/dev/null

cat <<EOF
[inject-lock] OK.
  LockID = ${LOCK_ID}

Ahora:
  1) terraform init -backend-config=backend.hcl
  2) terraform plan                 # verás el error de lock
  3) Investiga la fila:
       aws --endpoint-url=\$AWS_ENDPOINT_URL_DYNAMODB dynamodb get-item \\
         --table-name ${TABLE} --key '{"LockID":{"S":"${LOCK_ID}"}}'
  4) Cuando estés listo:
       terraform force-unlock ${LOCK_INFO_ID}
EOF
