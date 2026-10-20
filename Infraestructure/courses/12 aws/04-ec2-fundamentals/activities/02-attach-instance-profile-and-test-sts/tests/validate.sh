#!/usr/bin/env bash
# Structural validation for aws-04-02-attach-instance-profile-and-test-sts.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
# This convention follows the git-and-github course validators.
#
# `set -eu` catches unset vars and command failures; checks that may legally
# fail are wrapped in explicit if/else.

set -eu

BASE="${1:-/tmp/aws-04-02}"
passed=0
failed=0
skipped=0

ok()   { echo "  OK   $1"; passed=$((passed+1)); }
bad()  { echo "  FAIL $1"; failed=$((failed+1)); }
skip() { echo "  SKIP $1"; skipped=$((skipped+1)); }

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  bad "no existe $BASE"
  echo "RESULT: FAIL"
  exit 1
fi

# --- 1. Files -----------------------------------------------------------------
for f in main.tf variables.tf test-sts.sh instance-families.csv launch-template.yaml DECISION.md; do
  if [ -f "$BASE/$f" ]; then
    ok "existe $f"
  else
    bad "falta $f"
  fi
done

MAIN="$BASE/main.tf"
TEST="$BASE/test-sts.sh"
CSV="$BASE/instance-families.csv"
YAML="$BASE/launch-template.yaml"
DEC="$BASE/DECISION.md"

# --- 2. main.tf — policy minima ----------------------------------------------
if [ -f "$MAIN" ]; then
  if grep -q 'ssm:GetParameter' "$MAIN"; then
    ok "main.tf permite ssm:GetParameter"
  else
    bad "main.tf no incluye ssm:GetParameter"
  fi

  # Prohibir Action = "*" y Resource = "*".
  if grep -qE '"ssm:\*"|"\*"[[:space:]]*(,|\])' "$MAIN"; then
    # Si aparece "*" como accion, es violacion.
    if grep -qE 'actions[[:space:]]*=[[:space:]]*\[[[:space:]]*"\*"' "$MAIN" \
       || grep -qE 'actions[[:space:]]*=[[:space:]]*\[[[:space:]]*"ssm:\*"' "$MAIN"; then
      bad "main.tf usa Action='*' o 'ssm:*' (viola least privilege)"
    else
      ok "no se detecta Action='*' en actions"
    fi
  else
    ok "no hay Action='*' en main.tf"
  fi

  # Resource debe apuntar a parameter con prefijo controlado, no "*".
  if grep -qE 'resources[[:space:]]*=[[:space:]]*\[[[:space:]]*"\*"' "$MAIN"; then
    bad "main.tf usa Resource='*' (viola least privilege)"
  else
    ok "no se usa Resource='*'"
  fi

  if grep -qE 'arn:aws:ssm:' "$MAIN"; then
    ok "main.tf construye ARN concreto de SSM parameter"
  else
    bad "main.tf no construye ARN concreto (arn:aws:ssm:...)"
  fi

  if grep -q 'AmazonSSMManagedInstanceCore' "$MAIN"; then
    ok "main.tf mantiene AmazonSSMManagedInstanceCore"
  else
    bad "main.tf no incluye AmazonSSMManagedInstanceCore"
  fi

  if grep -q 'aws_iam_instance_profile' "$MAIN"; then
    ok "main.tf declara instance profile"
  else
    bad "main.tf no declara instance profile"
  fi
fi

# --- 3. test-sts.sh -----------------------------------------------------------
if [ -f "$TEST" ]; then
  if head -1 "$TEST" | grep -qE '^#!/usr/bin/env bash|^#!/bin/bash'; then
    ok "test-sts.sh tiene shebang bash"
  else
    bad "test-sts.sh sin shebang bash"
  fi

  if grep -qE '^set -eu( |$)|^set -eu[^ ]' "$TEST"; then
    ok "test-sts.sh declara set -eu"
  else
    bad "test-sts.sh no declara set -eu"
  fi

  # NO pipefail (regla del programa).
  if grep -qE 'set -o pipefail|set -eo pipefail|set -euo pipefail' "$TEST"; then
    bad "test-sts.sh usa pipefail (el programa pide NO usarlo en validadores/pipes con grep)"
  else
    ok "test-sts.sh no usa pipefail"
  fi

  for term in 'get-caller-identity' 'assumed-role' '169.254.169.254' 'X-aws-ec2-metadata-token' 'AccessDenied\|not authorized'; do
    if grep -qE "$term" "$TEST"; then
      ok "test-sts.sh menciona $term"
    else
      bad "test-sts.sh no menciona $term"
    fi
  done

  if bash -n "$TEST" 2>/dev/null; then
    ok "test-sts.sh pasa bash -n"
  else
    bad "test-sts.sh falla bash -n"
  fi

  if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -S warning "$TEST" >/dev/null 2>&1; then
      ok "test-sts.sh pasa shellcheck (warning)"
    else
      bad "test-sts.sh no pasa shellcheck (warning)"
    fi
  else
    skip "shellcheck no instalado"
  fi
fi

# --- 4. instance-families.csv ------------------------------------------------
if [ -f "$CSV" ]; then
  # Header debe tener las 7 columnas requeridas.
  if head -1 "$CSV" | grep -q 'type,family,vcpu,memory_gib,arch,use_case,on_demand_usd_per_hour_eu_west_1'; then
    ok "CSV con header de 7 columnas"
  else
    bad "CSV sin header requerido (type,family,vcpu,memory_gib,arch,use_case,on_demand_usd_per_hour_eu_west_1)"
  fi

  # Contar filas de datos (excluye header y comentarios '#').
  data_rows=$(grep -cvE '^#|^type,' "$CSV" || true)
  # grep -c suma 1 si no hay match segun version; filtramos lineas vacias.
  data_rows=$(awk 'NF && !/^#/ && !/^type,/' "$CSV" | wc -l | tr -d ' ')
  if [ "$data_rows" -ge 6 ]; then
    ok "CSV tiene $data_rows filas de datos (>=6)"
  else
    bad "CSV tiene $data_rows filas de datos (esperado >=6)"
  fi

  # Debe incluir Graviton (t4g, m7g, c7g, r7g, im4gn, etc.) — buscar '[tmcr]..g'.
  if grep -qE '[tmcrix][0-9]+gn?\.' "$CSV"; then
    ok "CSV incluye tipo Graviton"
  else
    bad "CSV no incluye tipos Graviton"
  fi

  # Debe incluir GPU (familia g* o p*).
  if grep -qE '(^|,)(g[0-9]+|p[0-9]+)\.' "$CSV"; then
    ok "CSV incluye familia GPU (g*/p*)"
  else
    bad "CSV no incluye familia GPU"
  fi

  # Fuente/fecha citada en comentario.
  if grep -qiE '#.*fuente|#.*source|#.*http' "$CSV"; then
    ok "CSV cita fuente de precios"
  else
    bad "CSV no cita fuente/fecha de los precios"
  fi
fi

# --- 5. launch-template.yaml -------------------------------------------------
if [ -f "$YAML" ]; then
  # YAML parseable (si python3+pyyaml disponibles).
  if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
    if python3 -c "import yaml,sys; yaml.safe_load(open('$YAML'))" >/dev/null 2>&1; then
      ok "launch-template.yaml parsea con PyYAML"
    else
      bad "launch-template.yaml no parsea con PyYAML"
    fi
  else
    skip "python3+pyyaml no disponibles — YAML parse omitido"
  fi

  for key in 'LaunchTemplateName' 'ImageId' 'InstanceType' 'IamInstanceProfile' 'MetadataOptions' 'HttpTokens' 'HttpPutResponseHopLimit' 'NetworkInterfaces' 'AssociatePublicIpAddress'; do
    if grep -q "$key" "$YAML"; then
      ok "YAML declara $key"
    else
      bad "YAML no declara $key"
    fi
  done

  if grep -qE 'HttpTokens:[[:space:]]*required' "$YAML"; then
    ok "YAML fuerza HttpTokens: required"
  else
    bad "YAML no fuerza HttpTokens: required"
  fi

  if grep -qE 'AssociatePublicIpAddress:[[:space:]]*false' "$YAML"; then
    ok "YAML fija AssociatePublicIpAddress: false"
  else
    bad "YAML no fija AssociatePublicIpAddress: false"
  fi

  if grep -qE '^[[:space:]]*(ImageId|InstanceType|HttpTokens|HttpPutResponseHopLimit|HttpEndpoint|Name|AssociatePublicIpAddress):[[:space:]]*null[[:space:]]*$' "$YAML"; then
    bad "YAML aun tiene valores 'null' sin resolver"
  else
    ok "YAML no deja valores null sin resolver"
  fi
fi

# --- 6. DECISION.md ----------------------------------------------------------
if [ -f "$DEC" ]; then
  for section in '1\.' '2\.' '3\.'; do
    if grep -qE "^#+ *$section" "$DEC"; then
      ok "DECISION.md cubre seccion $section"
    else
      bad "DECISION.md no cubre seccion $section"
    fi
  done

  todos=$(grep -c 'TODO' "$DEC" || true)
  if [ "$todos" -eq 0 ]; then
    ok "DECISION.md sin TODOs pendientes"
  else
    bad "DECISION.md tiene $todos TODOs sin resolver"
  fi
fi

# --- 7. Terraform fmt + validate (opcional) ---------------------------------
if command -v terraform >/dev/null 2>&1; then
  if ( cd "$BASE" && terraform fmt -check -diff ) >/dev/null 2>&1; then
    ok "terraform fmt limpio"
  else
    bad "terraform fmt detecta diferencias"
  fi

  if ( cd "$BASE" && terraform init -backend=false -input=false ) >/dev/null 2>&1; then
    if ( cd "$BASE" && terraform validate ) >/dev/null 2>&1; then
      ok "terraform validate pasa"
    else
      bad "terraform validate falla"
    fi
  else
    skip "terraform init -backend=false fallo"
  fi
else
  skip "terraform no instalado"
fi

# --- Fin ---------------------------------------------------------------------
echo
echo "----"
echo "PASS: $passed   FAIL: $failed   SKIP: $skipped"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
fi
echo "RESULT: FAIL"
exit 1
