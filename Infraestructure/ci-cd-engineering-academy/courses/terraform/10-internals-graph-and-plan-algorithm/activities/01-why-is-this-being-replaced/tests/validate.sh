#!/usr/bin/env bash
# Validate tf-10-01-why-is-this-being-replaced.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `grep -q` on upstream output, which can emit SIGPIPE (exit 141)
# on the upstream process when grep matches early. pipefail would promote that
# spurious SIGPIPE to a check failure.

WORK="${WORK_DIR:-/tmp/tf-10-01}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

if ! command -v terraform >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'terraform' no está instalado.
  - macOS:   brew tap hashicorp/tap && brew install hashicorp/tap/terraform
  - Linux:   https://developer.hashicorp.com/terraform/install
Verifica con: terraform version    (requiere >= 1.5)
EOF
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: 'jq' no está instalado. Instala jq >= 1.6."
  exit 0
fi

if [ ! -d "$WORK" ]; then
  bad "no existe $WORK (debes ejecutar el starter aquí)"
  echo -e "$report"
  echo "RESULT: FAIL"
  exit 1
fi

cd "$WORK" || { echo "RESULT: FAIL — no pude entrar a $WORK"; exit 1; }

if [ ! -f main.tf ]; then
  bad "no existe $WORK/main.tf"
  echo -e "$report"
  echo "RESULT: FAIL"
  exit 1
fi

# --- fix no usa ignore_changes para silenciar ---
if grep -q "ignore_changes" main.tf; then
  bad "main.tf usa 'ignore_changes' (prohibido: enmascara el bug)"
else
  ok "main.tf no usa 'ignore_changes'"
fi

# --- triggers sigue existiendo ---
if grep -q "triggers" main.tf; then
  ok "main.tf conserva el bloque 'triggers'"
else
  bad "main.tf eliminó 'triggers' entero (debía arreglarse, no borrarse)"
fi

# --- timestamp() ya no debe aparecer dentro de triggers ---
if grep -q "timestamp()" main.tf; then
  bad "main.tf sigue usando timestamp() (causa del bug)"
else
  ok "main.tf no usa timestamp()"
fi

# --- plan: debe decir No changes dos veces seguidas ---
if ! terraform init -input=false -no-color >/dev/null 2>&1; then
  bad "terraform init falló"
  echo -e "$report"
  echo "RESULT: FAIL"
  exit 1
fi

# apply para asentar el state con la nueva config
terraform apply -auto-approve -no-color >/dev/null 2>&1 || true

plan1="$(terraform plan -no-color -detailed-exitcode 2>&1)"
code1=$?
# -detailed-exitcode: 0 = no changes, 2 = changes present, 1 = error
if [ "$code1" -eq 0 ]; then
  ok "plan #1 reporta sin cambios"
else
  bad "plan #1 propone cambios (exit=$code1)"
fi

plan2="$(terraform plan -no-color -detailed-exitcode 2>&1)"
code2=$?
if [ "$code2" -eq 0 ]; then
  ok "plan #2 (reproducibilidad) también sin cambios"
else
  bad "plan #2 propone cambios (exit=$code2); el bug sigue"
fi

# --- writeup ---
wu="$WORK/writeup.md"
if [ ! -f "$wu" ]; then
  bad "no existe $wu"
else
  ok "writeup.md existe"
  if grep -qi "null_resource" "$wu"; then
    ok "writeup menciona null_resource"
  else
    bad "writeup no menciona el recurso afectado (null_resource)"
  fi
  if grep -qi "timestamp" "$wu"; then
    ok "writeup identifica la causa raíz (timestamp)"
  else
    bad "writeup no identifica la causa raíz (timestamp)"
  fi
fi

# --- evidencia: plan.json debería existir en el work dir ---
if [ -f "$WORK/plan.json" ]; then
  ok "plan.json presente como evidencia del diagnóstico"
else
  bad "no existe $WORK/plan.json (se pedía generarlo con terraform show -json)"
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
