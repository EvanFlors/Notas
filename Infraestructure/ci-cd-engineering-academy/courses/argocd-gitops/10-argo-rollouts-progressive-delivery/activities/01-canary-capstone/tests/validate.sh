#!/usr/bin/env bash
# Validate the structure of argo-10-01-canary-capstone.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks pipe
# into `grep -q`, which closes the pipe early and produces SIGPIPE on the
# upstream producer; pipefail would mark that as failure.

BASE="${1:-${BASE_DIR:-/tmp/argo-10-01}}"
ROLLOUT="$BASE/rollout.yaml"
SERVICES="$BASE/services.yaml"
passed=0
failed=0
report=""

ok()   { report+="  [OK]   $1\n"; passed=$((passed+1)); }
fail() { report+="  [FAIL] $1\n"; failed=$((failed+1)); }

if [ ! -f "$ROLLOUT" ]; then
  echo "FAIL: $ROLLOUT no existe. Copia starter/ a $BASE y edita según el README."
  exit 1
fi
if [ ! -f "$SERVICES" ]; then
  echo "FAIL: $SERVICES no existe."
  exit 1
fi

# --- Rollout checks ---
if grep -E "^apiVersion:[[:space:]]*argoproj\.io/v1alpha1" "$ROLLOUT" >/dev/null; then
  ok "apiVersion es argoproj.io/v1alpha1"
else
  fail "apiVersion debe ser argoproj.io/v1alpha1 (sigues con apps/v1)"
fi

if grep -E "^kind:[[:space:]]*Rollout" "$ROLLOUT" >/dev/null; then
  ok "kind es Rollout"
else
  fail "kind debe ser Rollout (sigues con Deployment)"
fi

if grep -E "^[[:space:]]*name:[[:space:]]*capstone\$" "$ROLLOUT" >/dev/null; then
  ok "metadata.name es capstone"
else
  fail "metadata.name debe ser 'capstone'"
fi

if grep -E "^[[:space:]]*canary:" "$ROLLOUT" >/dev/null; then
  ok "spec.strategy.canary presente"
else
  fail "falta spec.strategy.canary"
fi

if grep -E "canaryService:[[:space:]]*capstone-canary" "$ROLLOUT" >/dev/null; then
  ok "canaryService: capstone-canary"
else
  fail "falta o incorrecto canaryService: capstone-canary"
fi

if grep -E "stableService:[[:space:]]*capstone-stable" "$ROLLOUT" >/dev/null; then
  ok "stableService: capstone-stable"
else
  fail "falta o incorrecto stableService: capstone-stable"
fi

# Count steps / setWeight
if grep -E "setWeight:[[:space:]]*10\$" "$ROLLOUT" >/dev/null; then
  ok "step setWeight: 10 presente"
else
  fail "falta step setWeight: 10"
fi

if grep -E "setWeight:[[:space:]]*50\$" "$ROLLOUT" >/dev/null; then
  ok "step setWeight: 50 presente"
else
  fail "falta step setWeight: 50"
fi

if grep -E "setWeight:[[:space:]]*100\$" "$ROLLOUT" >/dev/null; then
  ok "step setWeight: 100 presente"
else
  fail "falta step setWeight: 100"
fi

# Manual pause -> `pause: {}` on one line or `pause:` followed by nothing meaningful.
if grep -E "pause:[[:space:]]*\{[[:space:]]*\}" "$ROLLOUT" >/dev/null; then
  ok "pause manual ({}) presente"
else
  fail "falta un pause manual: '{}' (promoción humana)"
fi

if grep -E "pause:[[:space:]]*\{[[:space:]]*duration" "$ROLLOUT" >/dev/null; then
  ok "pause temporizado (duration) presente"
else
  fail "falta un pause temporizado con duration"
fi

# strategy.type should NOT be present anymore (that was the Deployment default)
if grep -E "^[[:space:]]*type:[[:space:]]*RollingUpdate" "$ROLLOUT" >/dev/null; then
  fail "spec.strategy.type: RollingUpdate sigue presente (bórralo al migrar a Rollout canary)"
else
  ok "sin strategy.type residual del Deployment"
fi

# --- Services checks ---
if grep -E "^[[:space:]]*name:[[:space:]]*capstone-stable" "$SERVICES" >/dev/null; then
  ok "Service capstone-stable definido"
else
  fail "falta Service capstone-stable"
fi

if grep -E "^[[:space:]]*name:[[:space:]]*capstone-canary" "$SERVICES" >/dev/null; then
  ok "Service capstone-canary definido"
else
  fail "falta Service capstone-canary"
fi

# Both services must select app: capstone (expect at least 2 occurrences)
count=$(grep -cE "^[[:space:]]*app:[[:space:]]*capstone\$" "$SERVICES")
if [ "$count" -ge 2 ]; then
  ok "ambos Services seleccionan app: capstone"
else
  fail "los Services deben seleccionar 'app: capstone' (encontradas $count ocurrencias; se esperan >=2)"
fi

if grep -E "^---" "$SERVICES" >/dev/null; then
  ok "services.yaml tiene separador '---' entre documentos"
else
  fail "services.yaml debe contener dos documentos YAML separados por '---'"
fi

echo "== argo-10-01 structural validator =="
echo "BASE=$BASE"
printf "%b" "$report"
echo
total=$((passed+failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
