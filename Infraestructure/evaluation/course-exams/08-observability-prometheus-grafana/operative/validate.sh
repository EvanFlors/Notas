#!/usr/bin/env bash
# Validación local del ejercicio operativo.
# Emite SKIP si promtool o amtool no estan en PATH (ver EXAM.md).
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SOL="${HERE}/solution"
PASS=0
FAIL=0
SKIP=0

ok()   { echo "OK   : $*"; PASS=$((PASS+1)); }
bad()  { echo "FAIL : $*"; FAIL=$((FAIL+1)); }
skip() { echo "SKIP : $*"; SKIP=$((SKIP+1)); }

have() { command -v "$1" >/dev/null 2>&1; }

echo "== Precondiciones =="
if ! have promtool; then skip "promtool missing — OP-task-1/2/3/4 marcan SKIP"; HAVE_PROM=0; else HAVE_PROM=1; fi
if ! have amtool;  then skip "amtool missing — OP-task-5 (alertmanager) marca SKIP"; HAVE_AM=0; else HAVE_AM=1; fi

[[ -d "${SOL}" ]] || { bad "falta ${SOL}/ (debes crear la solución)"; exit 1; }

echo
echo "== Archivos requeridos =="
for f in prometheus.yml rules.yml rules_test.yml alertmanager.yml dashboards/service-red.json notes.md; do
  if [[ -s "${SOL}/${f}" ]]; then ok "existe solution/${f}"; else bad "falta solution/${f}"; fi
done

echo
echo "== promtool =="
if [[ ${HAVE_PROM} -eq 1 ]]; then
  promtool check config "${SOL}/prometheus.yml"       && ok "promtool check config"       || bad "promtool check config"
  promtool check rules  "${SOL}/rules.yml"            && ok "promtool check rules"        || bad "promtool check rules"
  ( cd "${SOL}" && promtool test rules rules_test.yml ) && ok "promtool test rules"       || bad "promtool test rules"
fi

echo
echo "== amtool =="
if [[ ${HAVE_AM} -eq 1 ]]; then
  amtool check-config "${SOL}/alertmanager.yml" && ok "amtool check-config" || bad "amtool check-config"
fi

echo
echo "== Convenciones mínimas =="
grep -q 'job:http_request_errors:ratio_rate5m' "${SOL}/rules.yml"  2>/dev/null && ok "recording rule ratio_rate5m presente" || bad "falta recording rule ratio_rate5m"
grep -q 'job:http_request_errors:ratio_rate1h' "${SOL}/rules.yml"  2>/dev/null && ok "recording rule ratio_rate1h presente" || bad "falta recording rule ratio_rate1h"
grep -q 'SLOBurnFast' "${SOL}/rules.yml"  2>/dev/null && ok "alerta SLOBurnFast presente" || bad "falta SLOBurnFast"
grep -q 'SLOBurnSlow' "${SOL}/rules.yml"  2>/dev/null && ok "alerta SLOBurnSlow presente" || bad "falta SLOBurnSlow"
grep -q 'runbook_url' "${SOL}/rules.yml"  2>/dev/null && ok "annotation runbook_url presente" || bad "falta annotation runbook_url"
grep -Eq 'inhibit_rules' "${SOL}/alertmanager.yml" 2>/dev/null && ok "inhibit_rules en Alertmanager" || bad "falta inhibit_rules"
grep -q 'group_by' "${SOL}/alertmanager.yml" 2>/dev/null && ok "group_by presente" || bad "falta group_by"
grep -q 'job:http_request_errors:ratio_rate5m' "${SOL}/dashboards/service-red.json" 2>/dev/null && ok "dashboard usa recording rule" || bad "dashboard no referencia recording rule"

echo
echo "== Red flags =="
# Secretos obvios / cardinalidad peligrosa
RF=0
for pat in 'user_id' 'request_id' 'email' 'trace_id' 'password:' 'bearer ' 'AKIA[0-9A-Z]{10}' 'ghp_[A-Za-z0-9]+' 'insecure_skip_verify: *true' 'cosign.*--insecure'; do
  if grep -REq "${pat}" "${SOL}" 2>/dev/null; then echo "RED-FLAG match: ${pat}"; RF=$((RF+1)); fi
done
[[ ${RF} -eq 0 ]] && ok "sin red flags detectadas por heuristica" || bad "red flags detectadas: ${RF}"

echo
echo "===================="
echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
echo "===================="
[[ ${FAIL} -eq 0 ]]
