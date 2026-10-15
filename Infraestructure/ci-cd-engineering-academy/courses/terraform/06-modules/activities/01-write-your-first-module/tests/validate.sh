#!/usr/bin/env bash
# Validate tf-06-01-write-your-first-module.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# `... | grep -q ...` patterns; if grep matches early it can trigger SIGPIPE
# (exit 141) on the upstream command, which pipefail would promote to a
# pipeline failure — a false negative.

WORK="${WORK_DIR:-/tmp/tf-06-01/greeting-site}"
passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight: terraform/tofu? ---
TF=""
if command -v terraform >/dev/null 2>&1; then
  TF="terraform"
elif command -v tofu >/dev/null 2>&1; then
  TF="tofu"
else
  cat <<EOF
SKIP: ni 'terraform' ni 'tofu' están instalados. Instala uno:
  - macOS:  brew install terraform    (o: brew install opentofu)
  - Linux:  https://developer.hashicorp.com/terraform/install
            https://opentofu.org/docs/intro/install/
Luego verifica: terraform version   (o: tofu version)   requiere >= 1.3
EOF
  exit 0
fi

ok "$($TF version | head -1) detectado"

echo "== Validando módulo en: $WORK =="

# --- 1. Estructura de archivos ---
required_files=(
  "$WORK/README.md"
  "$WORK/versions.tf"
  "$WORK/variables.tf"
  "$WORK/main.tf"
  "$WORK/outputs.tf"
  "$WORK/examples/basic/versions.tf"
  "$WORK/examples/basic/providers.tf"
  "$WORK/examples/basic/main.tf"
)
for f in "${required_files[@]}"; do
  if [ -f "$f" ]; then
    ok "existe $(basename "$(dirname "$f")")/$(basename "$f")"
  else
    bad "falta $f"
  fi
done

# Si falta estructura básica, no sigas con los chequeos semánticos.
if [ "$failed" -gt 0 ]; then
  printf "%b\n" "$report"
  echo "----"
  echo "PASS: $passed   FAIL: $failed"
  echo "RESULT: FAIL (estructura incompleta)"
  exit 1
fi

# --- 2. Módulo NO configura provider "..." {} ---
if grep -qE '^\s*provider\s*"' "$WORK/main.tf" "$WORK/variables.tf" "$WORK/outputs.tf" "$WORK/versions.tf" 2>/dev/null; then
  bad "el módulo contiene un bloque 'provider \"...\"' (debería estar solo en el root)"
else
  ok "el módulo no configura 'provider' (correcto)"
fi

# --- 3. versions.tf del módulo declara required_providers con local y random ---
if grep -q "required_providers" "$WORK/versions.tf" && \
   grep -q "hashicorp/local" "$WORK/versions.tf" && \
   grep -q "hashicorp/random" "$WORK/versions.tf"; then
  ok "versions.tf declara required_providers con local y random"
else
  bad "versions.tf no declara required_providers con hashicorp/local y hashicorp/random"
fi

# --- 4. variables.tf: cada bloque variable tiene description ---
# Simple heurística: cuenta 'variable "' y cuenta 'description' en el archivo.
nvars="$(grep -cE '^\s*variable\s+"' "$WORK/variables.tf" || true)"
ndesc="$(grep -cE '^\s*description\s*=' "$WORK/variables.tf" || true)"
if [ "$nvars" -ge 2 ] && [ "$ndesc" -ge "$nvars" ]; then
  ok "variables.tf: $nvars variables, $ndesc descriptions (todas documentadas)"
else
  bad "variables.tf: $nvars variables / $ndesc descriptions (cada variable debería tener 'description')"
fi

# --- 5. Al menos una validation {} ---
if grep -q "validation {" "$WORK/variables.tf" || grep -q "validation{" "$WORK/variables.tf"; then
  ok "variables.tf incluye al menos una validation {}"
else
  bad "variables.tf no incluye ningún bloque validation {}"
fi

# --- 6. outputs.tf: cada output tiene description ---
nouts="$(grep -cE '^\s*output\s+"' "$WORK/outputs.tf" || true)"
noutd="$(grep -cE '^\s*description\s*=' "$WORK/outputs.tf" || true)"
if [ "$nouts" -ge 2 ] && [ "$noutd" -ge "$nouts" ]; then
  ok "outputs.tf: $nouts outputs, $noutd descriptions"
else
  bad "outputs.tf: $nouts outputs / $noutd descriptions (cada output debería tener 'description')"
fi

# --- 7. README.md tiene las secciones ---
for section in "Qué hace" "Uso" "Inputs" "Outputs"; do
  if grep -qE "^##\s+${section}" "$WORK/README.md"; then
    ok "README.md tiene sección '## $section'"
  else
    bad "README.md no tiene '## $section'"
  fi
done

# --- 8. examples/basic/main.tf usa source = "../.." ---
if grep -qE 'source\s*=\s*"\.\./\.\."' "$WORK/examples/basic/main.tf"; then
  ok "examples/basic consume el módulo con source = \"../..\""
else
  bad "examples/basic/main.tf no usa source = \"../..\" (no copies-pegues, consume el módulo)"
fi

# --- 9. examples/basic: terraform init -input=false && terraform validate ---
pushd "$WORK/examples/basic" >/dev/null
rm -rf .terraform .terraform.lock.hcl

if $TF init -input=false -no-color >/tmp/tf-06-01.init.log 2>&1; then
  ok "$TF init en examples/basic OK"
else
  tail -20 /tmp/tf-06-01.init.log | sed 's/^/    /'
  bad "$TF init falló en examples/basic (ver /tmp/tf-06-01.init.log)"
fi

if $TF validate -no-color >/tmp/tf-06-01.validate.log 2>&1; then
  ok "$TF validate en examples/basic OK"
else
  tail -20 /tmp/tf-06-01.validate.log | sed 's/^/    /'
  bad "$TF validate falló (ver /tmp/tf-06-01.validate.log)"
fi
popd >/dev/null

echo
printf "%b\n" "$report"
echo "----"
echo "PASS: $passed   FAIL: $failed"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
