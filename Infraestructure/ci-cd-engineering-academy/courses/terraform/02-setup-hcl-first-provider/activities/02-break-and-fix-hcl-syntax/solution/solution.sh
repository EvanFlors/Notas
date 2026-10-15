#!/usr/bin/env bash
# Solucion de referencia para tf-02-02-break-and-fix-hcl-syntax.
# Monta /tmp/tf-02-02 con los .tf de solution/ y verifica fmt + validate + plan.

set -eu

WORK="${WORK_DIR:-/tmp/tf-02-02}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if ! command -v terraform >/dev/null 2>&1; then
  echo "SKIP: terraform no esta instalado."
  exit 0
fi

rm -rf "$WORK"
mkdir -p "$WORK"
cp "$HERE/versions.tf" "$HERE/providers.tf" "$HERE/main.tf" "$WORK/"

cd "$WORK"
terraform init -input=false
terraform fmt -check
terraform validate
terraform plan -input=false
