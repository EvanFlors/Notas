#!/usr/bin/env bash
# Validate tf-04-01-parameterize-the-stack.
#
# Checks:
#   1. Estructura de archivos del stack bajo $WORK_DIR (default /tmp/tf-04-01).
#   2. Declaraciones en variables.tf, outputs.tf, main.tf (vía grep).
#   3. Contenido mínimo de envs/dev.tfvars y envs/prod.tfvars.
#   4. Si 'terraform' está instalado, corre init + 3 plans para demostrar la
#      jerarquía de precedence experimentalmente.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Varios checks usan
# patrones como `grep -q ...` sobre pipes; cuando grep encuentra match temprano
# puede producir SIGPIPE (exit 141) en el upstream, y pipefail lo promovería a
# fallo del pipeline entero — un falso negativo.

WORK="${WORK_DIR:-/tmp/tf-04-01}"
passed=0
failed=0
report=""

ok()   { report+="  OK   $1\n"; passed=$((passed+1)); }
bad()  { report+="  FAIL $1\n"; failed=$((failed+1)); }
info() { report+="  --   $1\n"; }

echo "== Validando tf-04-01 en: $WORK =="

if [ ! -d "$WORK" ]; then
  echo "FAIL: no existe $WORK. Copia el starter según el Paso 1 del README."
  exit 1
fi

# ----------------------------------------------------------------------------
# 1. Estructura de archivos
# ----------------------------------------------------------------------------
for f in versions.tf variables.tf main.tf outputs.tf envs/dev.tfvars envs/prod.tfvars; do
  if [ -f "$WORK/$f" ]; then
    ok "existe $f"
  else
    bad "falta $f"
  fi
done

# ----------------------------------------------------------------------------
# 2. variables.tf: cada variable con type, description, validation donde aplica
# ----------------------------------------------------------------------------
VARS_FILE="$WORK/variables.tf"
if [ -f "$VARS_FILE" ]; then
  for v in environment project key_count rsa_bits tags; do
    if grep -Eq "variable[[:space:]]+\"$v\"" "$VARS_FILE"; then
      ok "variables.tf declara variable \"$v\""
    else
      bad "variables.tf NO declara variable \"$v\""
    fi
  done

  # description obligatoria en las 5
  desc_count="$(grep -c 'description[[:space:]]*=' "$VARS_FILE" || true)"
  if [ "${desc_count:-0}" -ge 5 ]; then
    ok "variables.tf tiene al menos 5 'description ='"
  else
    bad "variables.tf solo tiene $desc_count description (esperado >= 5)"
  fi

  # validation obligatoria para environment, project, key_count, rsa_bits
  val_count="$(grep -c 'validation[[:space:]]*{' "$VARS_FILE" || true)"
  if [ "${val_count:-0}" -ge 4 ]; then
    ok "variables.tf tiene al menos 4 'validation {'"
  else
    bad "variables.tf solo tiene $val_count validation blocks (esperado >= 4)"
  fi

  # tipos: object/map/number/string presentes
  if grep -q 'type[[:space:]]*=[[:space:]]*string' "$VARS_FILE" \
     && grep -q 'type[[:space:]]*=[[:space:]]*number' "$VARS_FILE" \
     && grep -Eq 'type[[:space:]]*=[[:space:]]*map\(' "$VARS_FILE"; then
    ok "variables.tf usa tipos string, number y map(...)"
  else
    bad "variables.tf no usa los tres tipos esperados (string, number, map(...))"
  fi
fi

# ----------------------------------------------------------------------------
# 3. outputs.tf: nombres exactos + description
# ----------------------------------------------------------------------------
OUTS_FILE="$WORK/outputs.tf"
if [ -f "$OUTS_FILE" ]; then
  for o in name_prefix manifest_path key_fingerprints effective_tags; do
    if grep -Eq "output[[:space:]]+\"$o\"" "$OUTS_FILE"; then
      ok "outputs.tf declara output \"$o\""
    else
      bad "outputs.tf NO declara output \"$o\""
    fi
  done
  odesc="$(grep -c 'description[[:space:]]*=' "$OUTS_FILE" || true)"
  if [ "${odesc:-0}" -ge 4 ]; then
    ok "outputs.tf tiene 4+ description"
  else
    bad "outputs.tf solo tiene $odesc description (esperado >= 4)"
  fi
fi

# ----------------------------------------------------------------------------
# 4. main.tf: usa var./local., NO literales dev/prod/payments_api hard-coded
# ----------------------------------------------------------------------------
MAIN_FILE="$WORK/main.tf"
if [ -f "$MAIN_FILE" ]; then
  if grep -q 'var\.' "$MAIN_FILE"; then
    ok "main.tf referencia var.*"
  else
    bad "main.tf no referencia ninguna var.*"
  fi
  if grep -q 'local\.' "$MAIN_FILE"; then
    ok "main.tf referencia local.*"
  else
    bad "main.tf no referencia ningún local.* (usa 'locals { }')"
  fi
  if grep -Eq '"(dev|prod|stg)"' "$MAIN_FILE"; then
    bad "main.tf aún tiene literales 'dev'/'prod'/'stg' (debería venir de var.environment)"
  else
    ok "main.tf no tiene literales de ambiente hard-coded"
  fi
  if grep -q '"payments_api"' "$MAIN_FILE"; then
    bad "main.tf aún tiene literal 'payments_api' (debería venir de var.project)"
  else
    ok "main.tf no tiene literal 'payments_api' hard-coded"
  fi
fi

# ----------------------------------------------------------------------------
# 5. envs/*.tfvars: valores mínimos
# ----------------------------------------------------------------------------
check_tfvars() {
  local file="$1" env_expected="$2" rsa_expected="$3"
  if [ ! -f "$file" ]; then return; fi
  if grep -Eq "environment[[:space:]]*=[[:space:]]*\"$env_expected\"" "$file"; then
    ok "$(basename "$file"): environment = \"$env_expected\""
  else
    bad "$(basename "$file"): falta/incorrecto 'environment = \"$env_expected\"'"
  fi
  if grep -Eq "project[[:space:]]*=[[:space:]]*\"[a-z]" "$file"; then
    ok "$(basename "$file"): project asignado"
  else
    bad "$(basename "$file"): falta 'project = \"...\"'"
  fi
  if grep -Eq "rsa_bits[[:space:]]*=[[:space:]]*$rsa_expected" "$file"; then
    ok "$(basename "$file"): rsa_bits = $rsa_expected"
  else
    bad "$(basename "$file"): rsa_bits != $rsa_expected"
  fi
}
check_tfvars "$WORK/envs/dev.tfvars"  "dev"  "2048"
check_tfvars "$WORK/envs/prod.tfvars" "prod" "4096"

# ----------------------------------------------------------------------------
# 6. terraform: init + 3 planes para probar precedence (si está instalado)
# ----------------------------------------------------------------------------
if command -v terraform >/dev/null 2>&1; then
  info "terraform detectado — ejecutando plan de precedence"
  cd "$WORK" || exit 1

  if terraform init -input=false -no-color >/tmp/tf-04-01-init.log 2>&1; then
    ok "terraform init OK"
  else
    bad "terraform init falló (ver /tmp/tf-04-01-init.log)"
  fi

  # Plan 1: solo -var-file=envs/dev.tfvars → environment = "dev"
  out1="$(terraform plan -input=false -no-color \
            -var-file=envs/dev.tfvars 2>/dev/null \
          | grep -E 'environment[[:space:]]*=|name_prefix' || true)"
  if echo "$out1" | grep -q 'payments_api-dev'; then
    ok "precedence 1/3: tfvars (dev) → name_prefix contiene 'payments_api-dev'"
  else
    bad "precedence 1/3: plan con dev.tfvars no muestra 'payments_api-dev' en name_prefix"
  fi

  # Plan 2: TF_VAR_environment=stg sobre dev.tfvars → gana TF_VAR → "stg"
  out2="$(TF_VAR_environment=stg terraform plan -input=false -no-color \
            -var-file=envs/dev.tfvars 2>/dev/null \
          | grep -E 'environment[[:space:]]*=|name_prefix' || true)"
  if echo "$out2" | grep -q 'payments_api-stg'; then
    ok "precedence 2/3: TF_VAR_environment=stg vence a dev.tfvars (name_prefix=payments_api-stg)"
  else
    bad "precedence 2/3: TF_VAR_environment=stg NO venció a dev.tfvars"
  fi

  # Plan 3: -var environment=prod + TF_VAR_environment=stg + dev.tfvars → gana -var → "prod"
  out3="$(TF_VAR_environment=stg terraform plan -input=false -no-color \
            -var-file=envs/dev.tfvars -var environment=prod 2>/dev/null \
          | grep -E 'environment[[:space:]]*=|name_prefix' || true)"
  if echo "$out3" | grep -q 'payments_api-prod'; then
    ok "precedence 3/3: -var environment=prod vence a TF_VAR_* y a tfvars"
  else
    bad "precedence 3/3: -var environment=prod NO ganó"
  fi

  # Plan 4: validation falla con environment=qa
  out4="$(terraform plan -input=false -no-color \
            -var-file=envs/dev.tfvars -var environment=qa 2>&1 || true)"
  if echo "$out4" | grep -q 'environment debe ser'; then
    ok "validation: environment=qa es rechazado con mensaje custom"
  else
    bad "validation: no se vio el error custom al pasar environment=qa"
  fi
else
  info "terraform NO está instalado — SKIP de los planes de precedence"
  info "   Instala Terraform:  https://developer.hashicorp.com/terraform/install"
  info "   o OpenTofu:         https://opentofu.org/docs/intro/install/"
fi

echo
printf "%b" "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
