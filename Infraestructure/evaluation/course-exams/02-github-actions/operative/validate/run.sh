#!/usr/bin/env bash
# Validación local del entregable operativo.
# Uso: ./run.sh <ruta-al-entregable>
# Requisitos locales (sin red, sin GitHub): bash, grep, awk, python3.
# Opcional: actionlint, zizmor (si están en PATH se ejecutan y pesan en el score).

set -u

ROOT="${1:-.}"
WF="${ROOT}/.github/workflows/ci.yml"
ADR="${ROOT}/ADR.md"
SC="${ROOT}/supply-chain.md"

pass=0; fail=0; warn=0
log()  { printf '  %s\n' "$*"; }
ok()   { printf '[OK]   %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '[FAIL] %s\n' "$*"; fail=$((fail+1)); }
soft() { printf '[WARN] %s\n' "$*"; warn=$((warn+1)); }

echo "== Validando entregable en: ${ROOT} =="

[[ -f "$WF" ]]  || { bad "Falta ${WF}"; exit 2; }
[[ -f "$ADR" ]] || bad "Falta ADR.md"
[[ -f "$SC"  ]] || bad "Falta supply-chain.md"

# --- Red flags (fallo descalificante) ---
if grep -nE 'pull_request_target' "$WF" | grep -qvE '#'; then
  if grep -nE 'ref:\s*\$\{\{\s*github\.event\.pull_request\.head\.sha' "$WF" >/dev/null; then
    bad "RED FLAG: pull_request_target + checkout del head del PR."
  else
    soft "pull_request_target presente: verificar que NO ejecuta código del PR."
  fi
else
  ok "No se usa pull_request_target (o se removió correctamente)."
fi

grep -nE 'permissions:\s*write-all' "$WF" >/dev/null \
  && bad "RED FLAG: permissions: write-all." \
  || ok "No hay permissions: write-all."

# Secretos literales (heurística): AKIA..., ghp_, patrón 40 hex en env/with.
if grep -nE '(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' "$WF" >/dev/null; then
  bad "RED FLAG: secreto hardcodeado detectado en el workflow."
else
  ok "No se detectan secretos hardcodeados."
fi

# --- Script injection: no interpolar github.event.* dentro de run: ---
if awk '
  /^[[:space:]]*run:[[:space:]]*\|?/,/^[^[:space:]]/ {
    if ($0 ~ /\$\{\{[[:space:]]*github\.event\./) { print NR": "$0; found=1 }
  }
  END { exit found?1:0 }
' "$WF"; then
  ok "run: no interpola github.event.* directamente."
else
  bad "Script injection: github.event.* interpolado dentro de run:."
fi

# --- Pins a SHA (40 hex) para actions de terceros ---
# Permitimos tags para actions/* (oficiales) pero exigimos SHA para el resto.
# Para rigor del examen exigimos SHA en TODAS.
unpinned=$(grep -nE '^\s*-?\s*uses:\s*[^@]+@(v?[0-9]+(\.[0-9]+){0,2}|main|master|latest)\s*$' "$WF" || true)
if [[ -n "$unpinned" ]]; then
  bad "Actions sin pin a SHA:"
  echo "$unpinned" | sed 's/^/      /'
else
  ok "Todas las actions pinneadas a SHA."
fi

# --- permissions explícitas a nivel workflow ---
grep -nE '^permissions:' "$WF" >/dev/null \
  && ok "Bloque permissions: declarado a nivel workflow." \
  || bad "Falta bloque permissions: a nivel workflow (least-privilege)."

# --- OIDC: id-token write + role-to-assume, sin AWS_ACCESS_KEY_ID en env ---
if grep -nE 'id-token:\s*write' "$WF" >/dev/null \
   && grep -nE 'role-to-assume' "$WF" >/dev/null; then
  ok "OIDC configurado (id-token: write + role-to-assume)."
else
  bad "No se detecta migración a OIDC (id-token: write + role-to-assume)."
fi

grep -nE 'AWS_(ACCESS|SECRET)_KEY' "$WF" >/dev/null \
  && bad "Siguen apareciendo credenciales AWS de larga vida." \
  || ok "Sin credenciales AWS de larga vida."

# --- environment: production con approval conceptualmente respaldado en ADR ---
grep -nE '^\s*environment:\s*(production|prod)' "$WF" >/dev/null \
  && ok "Job de deploy asociado a environment production." \
  || bad "Falta environment: production en el job de deploy."

# --- concurrency ---
grep -nE '^\s*concurrency:' "$WF" >/dev/null \
  && ok "Bloque concurrency: presente." \
  || bad "Falta concurrency: (prod no debe deployar en paralelo)."

# --- cache de dependencias ---
grep -nE 'cache:\s*(pip|poetry|npm|yarn)|actions/cache@' "$WF" >/dev/null \
  && ok "Cache de dependencias configurada." \
  || soft "No se detecta cache de dependencias (penalización menor)."

# --- supply chain: SBOM + attestation + cosign ---
if grep -qE 'anchore/sbom-action|aquasecurity/trivy|syft'           "$WF" \
&& grep -qE 'actions/attest-build-provenance|actions/attest-sbom'   "$WF" \
&& grep -qE 'sigstore/cosign-installer|cosign sign'                 "$WF"; then
  ok "Supply chain: SBOM + attestation + cosign presentes."
else
  bad "Falta cadena supply chain completa (SBOM + attestation + cosign)."
fi

# --- actionlint / zizmor si existen ---
if command -v actionlint >/dev/null 2>&1; then
  actionlint "$WF" && ok "actionlint pasa." || bad "actionlint reporta problemas."
else
  soft "actionlint no instalado — omitido."
fi
if command -v zizmor >/dev/null 2>&1; then
  zizmor "$WF" && ok "zizmor pasa." || bad "zizmor reporta problemas."
else
  soft "zizmor no instalado — omitido."
fi

# --- ADR mínimo ---
if [[ -f "$ADR" ]]; then
  for kw in "pull_request_target" "pinning" "OIDC" "permissions" "concurrency"; do
    grep -qi "$kw" "$ADR" && ok "ADR cubre '${kw}'." || bad "ADR no cubre '${kw}'."
  done
fi

echo
echo "== Resumen: ${pass} ok | ${fail} fail | ${warn} warn =="
[[ $fail -eq 0 ]] || exit 1
