#!/usr/bin/env bash
# Validate tf-02-02-break-and-fix-hcl-syntax.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `terraform validate -json | grep -q ...`; if grep matches early,
# the upstream pipeline step may receive SIGPIPE (exit 141), and pipefail would
# turn that into a false negative.

WORK="${WORK_DIR:-/tmp/tf-02-02}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

if ! command -v terraform >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'terraform' no esta instalado. Instala con una de:
  - macOS Homebrew:   brew install terraform
  - tfenv:            tfenv install latest && tfenv use latest
  - asdf:             asdf plugin add terraform && asdf install terraform latest
  - Binario oficial:  https://developer.hashicorp.com/terraform/install
Luego verifica: terraform version    (requiere >= 1.5)
EOF
  exit 0
fi

ver="$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | head -1 | cut -d'"' -f4)"
if [ -z "$ver" ]; then
  ver="$(terraform version 2>/dev/null | head -1 | awk '{print $2}' | tr -d 'v')"
fi
major="${ver%%.*}"; rest="${ver#*.}"; minor="${rest%%.*}"
if [ -z "$major" ] || [ -z "$minor" ]; then
  bad "no pude parsear la version de terraform ('$ver')"
elif [ "$major" -lt 1 ] || { [ "$major" -eq 1 ] && [ "$minor" -lt 5 ]; }; then
  bad "terraform $ver < 1.5"
else
  ok "terraform $ver detectado"
fi

echo "== Validando $WORK =="

if [ ! -d "$WORK" ]; then
  bad "no existe directorio $WORK (ejecuta la actividad antes)"
  echo -e "$report"
  echo "RESULT: FAIL"
  exit 1
fi

cd "$WORK"

for f in versions.tf providers.tf main.tf; do
  if [ -f "$f" ]; then
    ok "existe $f"
  else
    bad "no existe $f (copia el starter antes)"
  fi
done

# Asegura init idempotente (silencioso si ya existe .terraform)
if [ ! -d .terraform ]; then
  if terraform init -input=false >/dev/null 2>&1; then
    ok "terraform init pasa"
  else
    bad "terraform init falla; revisa versions.tf"
  fi
else
  ok ".terraform/ ya presente"
fi

# fmt -check
if terraform fmt -check >/dev/null 2>&1; then
  ok "terraform fmt -check pasa (sin diferencias de formato)"
else
  bad "terraform fmt -check falla (hay formato pendiente — corre 'terraform fmt')"
fi

# validate
if terraform validate >/dev/null 2>&1; then
  ok "terraform validate pasa"
else
  bad "terraform validate falla; corre 'terraform validate' para ver detalles"
fi

# Chequeos semanticos: nombres y atributos esperados
if [ -f main.tf ]; then
  grep -q 'resource "random_pet" "codename"' main.tf && ok "random_pet.codename preservado"           || bad "cambiaste el nombre del random_pet; manten 'codename'"
  grep -q 'resource "local_file" "badge"'    main.tf && ok "local_file.badge preservado"              || bad "cambiaste el nombre del local_file; manten 'badge'"
  grep -q 'file_permission'                  main.tf && ok "usa el atributo correcto file_permission" || bad "falta file_permission (el typo 'permissons' sigue?)"
  if grep -q 'random_pet.pet'                main.tf; then
    bad "aun hay referencias a 'random_pet.pet' (debe ser 'random_pet.codename')"
  else
    ok "no quedan referencias a random_pet.pet"
  fi
  if grep -q 'length *= *"'                  main.tf; then
    bad "'length' sigue siendo string; debe ser numero"
  else
    ok "'length' es numerico"
  fi
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
