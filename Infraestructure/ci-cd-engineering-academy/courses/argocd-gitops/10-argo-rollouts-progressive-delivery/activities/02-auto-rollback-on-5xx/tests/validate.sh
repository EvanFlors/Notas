#!/usr/bin/env bash
# Validate the structure of argo-10-02-auto-rollback-on-5xx.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks pipe
# into `grep -q`, which can produce SIGPIPE on the producer. pipefail would
# treat that as a failure.

BASE="${1:-${BASE_DIR:-/tmp/argo-10-02}}"
AT="$BASE/analysistemplate.yaml"
RO="$BASE/rollout.yaml"
passed=0
failed=0
report=""

ok()   { report+="  [OK]   $1\n"; passed=$((passed+1)); }
fail() { report+="  [FAIL] $1\n"; failed=$((failed+1)); }

if [ ! -f "$AT" ]; then
  echo "FAIL: $AT no existe. Copia starter/ a $BASE y edita según el README."
  exit 1
fi
if [ ! -f "$RO" ]; then
  echo "FAIL: $RO no existe."
  exit 1
fi

# --- AnalysisTemplate checks ---
if grep -E "^kind:[[:space:]]*AnalysisTemplate" "$AT" >/dev/null; then
  ok "kind: AnalysisTemplate"
else
  fail "kind debe ser AnalysisTemplate"
fi

if grep -E "^[[:space:]]*name:[[:space:]]*error-rate-5xx" "$AT" >/dev/null; then
  ok "metadata.name: error-rate-5xx"
else
  fail "metadata.name debe ser 'error-rate-5xx'"
fi

if grep -E "name:[[:space:]]*service-name" "$AT" >/dev/null; then
  ok "arg service-name declarado"
else
  fail "falta spec.args.service-name"
fi

if grep -E "name:[[:space:]]*prometheus-address" "$AT" >/dev/null; then
  ok "arg prometheus-address declarado"
else
  fail "falta spec.args.prometheus-address"
fi

if grep -E "^[[:space:]]*prometheus:" "$AT" >/dev/null; then
  ok "provider prometheus presente"
else
  fail "falta provider prometheus"
fi

if grep -E "address:" "$AT" >/dev/null; then
  ok "provider.prometheus.address presente"
else
  fail "falta provider.prometheus.address"
fi

if grep -E "query:" "$AT" >/dev/null; then
  ok "provider.prometheus.query presente"
else
  fail "falta provider.prometheus.query"
fi

if grep -E "code=~\"5\\.\\.\"" "$AT" >/dev/null; then
  ok "query filtra code=~\"5..\""
else
  fail "la query debe filtrar status 5xx (code=~\"5..\")"
fi

if grep -E "\\{\\{args\\.service-name\\}\\}" "$AT" >/dev/null; then
  ok "query interpola {{args.service-name}}"
else
  fail "la query debe usar {{args.service-name}} para parametrizar el servicio"
fi

if grep -E "successCondition:" "$AT" >/dev/null; then
  ok "successCondition presente"
else
  fail "falta successCondition"
fi

if grep -E "failureCondition:" "$AT" >/dev/null; then
  ok "failureCondition presente"
else
  fail "falta failureCondition"
fi

if grep -E "failureLimit:[[:space:]]*[1-9]" "$AT" >/dev/null; then
  ok "failureLimit >= 1"
else
  fail "falta failureLimit (>= 1)"
fi

if grep -E "^[[:space:]]*interval:" "$AT" >/dev/null; then
  ok "interval presente"
else
  fail "falta interval"
fi

if grep -E "^[[:space:]]*count:[[:space:]]*[1-9]" "$AT" >/dev/null; then
  ok "count >= 1"
else
  fail "falta count"
fi

# Metric count: exactly one metric. Count '- name:' entries under `metrics:`.
# Simplest heuristic: lines matching '^    - name:' between metrics: and next top-level.
# Easier: check that `metrics:` appears once.
metrics_blocks=$(grep -cE "^[[:space:]]*metrics:" "$AT")
if [ "$metrics_blocks" -eq 1 ]; then
  ok "una sola sección metrics:"
else
  fail "se esperaba una sección 'metrics:' (encontradas $metrics_blocks)"
fi

# --- Rollout checks ---
if grep -E "^kind:[[:space:]]*Rollout" "$RO" >/dev/null; then
  ok "rollout.yaml: kind Rollout"
else
  fail "rollout.yaml debe tener kind: Rollout"
fi

if grep -E "templateName:[[:space:]]*error-rate-5xx" "$RO" >/dev/null; then
  ok "Rollout referencia templateName: error-rate-5xx"
else
  fail "falta step analysis con templateName: error-rate-5xx"
fi

if grep -E "^[[:space:]]*-[[:space:]]*analysis:" "$RO" >/dev/null; then
  ok "existe al menos un step 'analysis:'"
else
  fail "falta un step analysis dentro de spec.strategy.canary.steps"
fi

# Must pass the service-name arg so the template can interpolate it.
if grep -E "name:[[:space:]]*service-name" "$RO" >/dev/null; then
  ok "step analysis pasa arg service-name"
else
  fail "el step analysis debe pasar args.service-name al template"
fi

echo "== argo-10-02 structural validator =="
echo "BASE=$BASE"
printf "%b" "$report"
echo
total=$((passed+failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
