#!/usr/bin/env bash
# End-to-end de la actividad en MODE=local. Idempotente.
# Note: NO pipefail — algunos pipes con grep -q pueden SIGPIPE y dar falsos negativos.
set -eu

MODE="${MODE:-local}"
WORK="${WORK:-/tmp/tf-11-01}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"     # .../solution/
START="$HERE/../starter"
LS_PORT="${LS_PORT:-4566}"

if ! command -v terraform >/dev/null 2>&1 && ! command -v tofu >/dev/null 2>&1; then
  echo "SKIP: terraform/tofu no instalado"
  exit 0
fi
TF="$(command -v terraform || command -v tofu)"

mkdir -p "$WORK"
cp -f "$START/main.tf"        "$WORK/main.tf"
cp -f "$START/backend.hcl"    "$WORK/backend.hcl"
mkdir -p "$WORK/scripts"
cp -f "$START/scripts/bootstrap-backend.sh" "$WORK/scripts/bootstrap-backend.sh"
chmod +x "$WORK/scripts/bootstrap-backend.sh"

cd "$WORK"

# Paso 1: apply con backend local.
"$TF" init -upgrade >/dev/null
"$TF" apply -auto-approve >/dev/null

# Paso 2: bootstrap backend.
MODE="$MODE" bash scripts/bootstrap-backend.sh

if [ "$MODE" = "local" ]; then
  export AWS_ACCESS_KEY_ID=test
  export AWS_SECRET_ACCESS_KEY=test
  export AWS_DEFAULT_REGION=us-east-1
  export AWS_ENDPOINT_URL_S3="http://localhost:${LS_PORT}"
  export AWS_ENDPOINT_URL_DYNAMODB="http://localhost:${LS_PORT}"
fi

# Paso 3: añadir backend "s3" {} si no está (solución ya lo tiene; usamos la solución).
cp -f "$HERE/main.tf"     "$WORK/main.tf"
cp -f "$HERE/backend.hcl" "$WORK/backend.hcl"

# Paso 4: migrar state.
"$TF" init -backend-config=backend.hcl -migrate-state -force-copy

# Paso 5: apply remoto para que el lock se adquiera y libere.
"$TF" apply -auto-approve >/dev/null

echo "OK: full-run completo. Corre tests/validate.sh para verificar."
