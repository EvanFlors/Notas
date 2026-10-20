#!/usr/bin/env bash
# Validate cap-06-02-bootstrap-backend-local.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# `grep` / `find` outputs together; a SIGPIPE on the upstream command would be
# promoted to a pipeline failure under pipefail — a false negative.
set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"
STAGE_ROOT="$(cd "$HERE/../.." && pwd)"
TF_ROOT="$STAGE_ROOT/terraform"

passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }
skip(){ report+="  SKIP $1\n"; }

echo "== Validando stacks Terraform en: $TF_ROOT =="

for cloud in aws gcp azure; do
  dir="$TF_ROOT/$cloud"
  if [ ! -d "$dir" ]; then
    bad "falta carpeta $dir"
    continue
  fi
  for f in main.tf variables.tf outputs.tf versions.tf backend.tf; do
    if [ -f "$dir/$f" ]; then
      ok "$cloud/$f existe"
    else
      bad "$cloud/$f no existe"
    fi
  done
done

# backend.tf debe ser parcial — no líneas no comentadas con bucket/storage/etc.
# Buscamos declaraciones activas de bucket/dynamodb_table/storage_account_name/resource_group_name.
for cloud in aws gcp azure; do
  bf="$TF_ROOT/$cloud/backend.tf"
  [ -f "$bf" ] || continue
  # Grep líneas no comentadas que asignen a esos campos.
  if grep -vE '^\s*#' "$bf" | grep -Eq '^\s*(bucket|dynamodb_table|storage_account_name|resource_group_name|container_name)\s*=' ; then
    bad "$cloud/backend.tf tiene valores embebidos — debe ser parcial"
  else
    ok "$cloud/backend.tf es parcial"
  fi
done

# Buscar IDs plausiblemente reales en cualquier .tf
# AWS account id: 12 dígitos seguidos como string.
if find "$TF_ROOT" -name '*.tf' -print0 | xargs -0 grep -HE '"[0-9]{12}"' ; then
  bad "posible AWS account id (12 dígitos) encontrado en algún .tf"
else
  ok "no se encontraron AWS account ids literales"
fi

# Azure tenant GUID: hhhhhhhh-hhhh-hhhh-hhhh-hhhhhhhhhhhh.
if find "$TF_ROOT" -name '*.tf' -print0 | xargs -0 grep -HiE '"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"' ; then
  bad "posible GUID (tenant/subscription id) encontrado"
else
  ok "no se encontraron GUIDs tenant/subscription literales"
fi

# GCP: project id default es 'example-project-id'. Si cambió a algo que no empieza con 'example-' marcamos.
if grep -E 'default\s*=\s*"[a-z]' "$TF_ROOT/gcp/variables.tf" | grep -v 'example-' | grep -q 'project_id'; then
  bad "gcp/variables.tf project_id default parece real"
else
  ok "gcp project_id default es placeholder"
fi

# terraform validate opt-in.
if command -v terraform >/dev/null 2>&1; then
  for cloud in aws gcp azure; do
    dir="$TF_ROOT/$cloud"
    if terraform -chdir="$dir" init -backend=false -input=false -no-color >/dev/null 2>&1; then
      if terraform -chdir="$dir" validate -no-color >/dev/null 2>&1; then
        ok "terraform validate verde en $cloud"
      else
        bad "terraform validate falla en $cloud"
      fi
    else
      bad "terraform init -backend=false falla en $cloud"
    fi
  done
else
  skip "terraform binary no encontrado — opt-in"
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
