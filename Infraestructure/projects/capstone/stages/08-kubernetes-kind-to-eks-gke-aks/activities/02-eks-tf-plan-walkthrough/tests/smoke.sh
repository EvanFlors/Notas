#!/usr/bin/env bash
# Smoke: terraform init -backend=false + validate en las 3 nubes.
#
# NOTE: deliberately NO `set -o pipefail`. Grep en pipelines con
# pipefail reportaria SIGPIPE (141) espurio cuando grep sale pronto.
set -eu

STAGE_DIR="${STAGE_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"

if ! command -v terraform >/dev/null 2>&1; then
  echo "SKIP: terraform no instalado"
  exit 0
fi

for cloud in aws/eks gcp/gke azure/aks; do
  dir="$STAGE_DIR/terraform/$cloud"
  echo "== smoke: terraform init+validate $cloud =="
  (
    cd "$dir"
    terraform init -backend=false -input=false -no-color >/dev/null
    terraform validate -no-color
  )
done

echo "smoke OK"
