#!/usr/bin/env bash
# Validate tf-02-01-first-apply.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `terraform output -json | grep -q ...`; if grep matches early,
# the upstream pipeline step may receive SIGPIPE (exit 141), and pipefail would
# turn that into a false negative.

WORK="${WORK_DIR:-/tmp/tf-02-01}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight ---
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

major="${ver%%.*}"
rest="${ver#*.}"
minor="${rest%%.*}"

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

# --- 1. Archivos esperados ---
for f in versions.tf main.tf .terraform.lock.hcl notas-lockfile.md; do
  if [ -f "$f" ]; then
    ok "existe $f"
  else
    bad "no existe $f en $WORK"
  fi
done

# --- 2. versions.tf declara los tres providers ---
if [ -f versions.tf ]; then
  for p in null random local; do
    if grep -q "hashicorp/$p" versions.tf; then
      ok "versions.tf declara hashicorp/$p"
    else
      bad "versions.tf no declara hashicorp/$p"
    fi
  done
  if grep -q 'required_version' versions.tf; then
    ok "versions.tf tiene required_version"
  else
    bad "versions.tf no tiene required_version"
  fi
fi

# --- 3. main.tf tiene los recursos pedidos ---
if [ -f main.tf ]; then
  grep -q 'resource "random_pet" "codename"'   main.tf && ok "random_pet.codename declarado"   || bad "falta random_pet.codename"
  grep -q 'resource "random_string" "suffix"'  main.tf && ok "random_string.suffix declarado"  || bad "falta random_string.suffix"
  grep -q 'resource "null_resource" "log"'     main.tf && ok "null_resource.log declarado"     || bad "falta null_resource.log"
  grep -q 'resource "local_file" "badge"'      main.tf && ok "local_file.badge declarado"      || bad "falta local_file.badge"
  grep -q 'output "badge_path"'                main.tf && ok "output badge_path declarado"     || bad "falta output badge_path"
  grep -q 'output "codename"'                  main.tf && ok "output codename declarado"       || bad "falta output codename"
fi

# --- 4. terraform validate pasa ---
if terraform validate >/dev/null 2>&1; then
  ok "terraform validate pasa"
else
  bad "terraform validate falla"
fi

# --- 5. Lockfile menciona los tres providers ---
if [ -f .terraform.lock.hcl ]; then
  for p in null random local; do
    if grep -q "hashicorp/$p" .terraform.lock.hcl; then
      ok "lockfile fija provider $p"
    else
      bad "lockfile no fija provider $p (corriste 'terraform init'?)"
    fi
  done
  if grep -q '^  version' .terraform.lock.hcl; then
    ok "lockfile tiene version resuelta"
  else
    bad "lockfile no parece tener version"
  fi
  if grep -q 'h1:' .terraform.lock.hcl; then
    ok "lockfile tiene hashes h1:"
  else
    bad "lockfile no tiene hashes h1:"
  fi
fi

# --- 6. Notas mencionan lo pedido ---
if [ -f notas-lockfile.md ]; then
  for kw in h1 random local null version hashes; do
    if grep -qi "$kw" notas-lockfile.md; then
      ok "notas mencionan '$kw'"
    else
      bad "notas no mencionan '$kw'"
    fi
  done
fi

# --- 7. Estado final: NO debe quedar local_file vivo (debe haber hecho destroy) ---
#     Aceptamos dos finales:
#       (a) state tiene recursos y el archivo existe (aun no destruyeron)   -> FAIL
#       (b) state vacio y el archivo no existe                              -> OK
state_count="$(terraform state list 2>/dev/null | wc -l | tr -d ' ')"
if [ "$state_count" = "0" ]; then
  ok "state vacio (hiciste destroy)"
else
  bad "state tiene $state_count recurso(s); corre 'terraform destroy -auto-approve' para cerrar la actividad"
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
