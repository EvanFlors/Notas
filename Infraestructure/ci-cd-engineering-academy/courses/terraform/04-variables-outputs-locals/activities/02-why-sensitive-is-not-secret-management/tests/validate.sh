#!/usr/bin/env bash
# Validate tf-04-02-why-sensitive-is-not-secret-management.
#
# Checks:
#   1. ANALYSIS.md existe en $WORK_DIR (default /tmp/tf-04-02).
#   2. Contiene el grep demo del Paso 3 y una salida con 'DUMMY-SECRET-DO-NOT-USE-'.
#   3. Enumera al menos 3 lugares donde el valor sigue siendo recuperable.
#   4. Afirma explícitamente que sensitive=true no cifra.
#   5. Describe la mitigación: secret manager + data source + backend.
#   6. Si terraform está instalado y hay terraform.tfstate, verifica que el valor
#      dummy aparece en el state en claro (evidencia independiente).
#
# Note: we deliberately do NOT enable `set -o pipefail`. Varios checks usan
# `grep -q ...` sobre pipes; cuando grep matchea temprano puede dispararse
# SIGPIPE (exit 141) en el upstream, y pipefail convertiría eso en falso
# negativo.

WORK="${WORK_DIR:-/tmp/tf-04-02}"
ANALYSIS="$WORK/ANALYSIS.md"
STATE="$WORK/terraform.tfstate"
passed=0
failed=0
report=""

ok()   { report+="  OK   $1\n"; passed=$((passed+1)); }
bad()  { report+="  FAIL $1\n"; failed=$((failed+1)); }
info() { report+="  --   $1\n"; }

echo "== Validando tf-04-02 en: $WORK =="

if [ ! -d "$WORK" ]; then
  echo "FAIL: no existe $WORK. Copia el starter según el Paso 1 del README."
  exit 1
fi

# ----------------------------------------------------------------------------
# 1. ANALYSIS.md existe
# ----------------------------------------------------------------------------
if [ ! -f "$ANALYSIS" ]; then
  echo "FAIL: no existe $ANALYSIS."
  echo "       Copia starter/ANALYSIS.md.template a $WORK/ANALYSIS.md y rellénalo."
  exit 1
fi
ok "ANALYSIS.md existe"

# ----------------------------------------------------------------------------
# 2. Contiene la demostración con grep
# ----------------------------------------------------------------------------
if grep -q "DUMMY-SECRET-DO-NOT-USE-" "$ANALYSIS"; then
  ok "ANALYSIS.md menciona la cadena marcadora 'DUMMY-SECRET-DO-NOT-USE-'"
else
  bad "ANALYSIS.md no muestra la cadena 'DUMMY-SECRET-DO-NOT-USE-' (pega la salida del grep)"
fi

if grep -Eq "grep .*terraform\.tfstate" "$ANALYSIS"; then
  ok "ANALYSIS.md incluye un grep sobre terraform.tfstate"
else
  bad "ANALYSIS.md no incluye el comando grep sobre terraform.tfstate"
fi

if grep -Eqi "BEGIN (RSA )?PRIVATE KEY" "$ANALYSIS"; then
  ok "ANALYSIS.md menciona la detección de PEM privado en el state"
else
  bad "ANALYSIS.md no menciona la búsqueda de 'BEGIN PRIVATE KEY' en el state"
fi

# ----------------------------------------------------------------------------
# 3. Enumera al menos 3 lugares donde el valor sigue siendo recuperable
# ----------------------------------------------------------------------------
places_hit=0
for pat in "state" "plan" "output -raw" "provider" "backend" "log"; do
  if grep -qi "$pat" "$ANALYSIS"; then
    places_hit=$((places_hit+1))
  fi
done
if [ "$places_hit" -ge 3 ]; then
  ok "ANALYSIS.md menciona al menos 3 superficies de exposición ($places_hit/6 detectadas)"
else
  bad "ANALYSIS.md solo menciona $places_hit/6 superficies esperadas (state/plan/output -raw/provider/backend/log)"
fi

# ----------------------------------------------------------------------------
# 4. Afirmación clara: sensitive no cifra
# ----------------------------------------------------------------------------
if grep -Eqi "sensitive[^.]{0,30}no (cifra|encripta|protege)" "$ANALYSIS" \
   || grep -Eqi "no (cifra|encripta|protege)[^.]{0,40}sensitive" "$ANALYSIS"; then
  ok "ANALYSIS.md afirma explícitamente que 'sensitive' no cifra/protege"
else
  bad "ANALYSIS.md no afirma de forma clara que 'sensitive' no cifra el state"
fi

# ----------------------------------------------------------------------------
# 5. Mitigación: secret manager + data source + backend
# ----------------------------------------------------------------------------
if grep -Eqi "secret.manager|vault|secrets manager|secret manager|sops" "$ANALYSIS"; then
  ok "ANALYSIS.md propone un secret manager como mitigación"
else
  bad "ANALYSIS.md no cita ningún secret manager (Vault / Secrets Manager / SOPS / …)"
fi

if grep -Eq "data[[:space:]]+\"" "$ANALYSIS" || grep -qi "data source" "$ANALYSIS"; then
  ok "ANALYSIS.md menciona el uso de 'data' source"
else
  bad "ANALYSIS.md no menciona el patrón 'data' source"
fi

if grep -qi "backend" "$ANALYSIS"; then
  ok "ANALYSIS.md habla de proteger el state al nivel del 'backend'"
else
  bad "ANALYSIS.md no menciona 'backend' en el contexto de la mitigación"
fi

# No deben quedar placeholders [RELLENAR]
if grep -q "\[RELLENAR" "$ANALYSIS"; then
  bad "ANALYSIS.md todavía tiene placeholders '[RELLENAR...]' sin completar"
else
  ok "ANALYSIS.md no tiene placeholders '[RELLENAR...]'"
fi

# ----------------------------------------------------------------------------
# 6. Evidencia independiente desde el state (si terraform está instalado)
# ----------------------------------------------------------------------------
if [ -f "$STATE" ]; then
  dummy_hits="$(grep -c 'DUMMY-SECRET-DO-NOT-USE-' "$STATE" || true)"
  if [ "${dummy_hits:-0}" -ge 1 ]; then
    ok "terraform.tfstate contiene $dummy_hits occurrencia(s) de 'DUMMY-SECRET-DO-NOT-USE-' (en claro)"
  else
    bad "terraform.tfstate no contiene la cadena dummy (¿aplicaste con el starter correcto?)"
  fi
else
  if command -v terraform >/dev/null 2>&1; then
    info "No existe $STATE — corre 'terraform apply -auto-approve' en $WORK"
  else
    info "terraform NO está instalado y no hay terraform.tfstate; se valida solo ANALYSIS.md."
    info "   Instala Terraform: https://developer.hashicorp.com/terraform/install"
  fi
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
