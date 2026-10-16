#!/usr/bin/env bash
# Validate obs-06-02-debug-missing-targets.
#
# For each scenario N in 1..4, port-forward the scenario Prometheus and
# check that /api/v1/targets contains an active target with job="k8s-pods"
# in namespace obs-sN.
#
# Note: pipefail is NOT set because `curl | grep -q` can SIGPIPE the
# upstream curl once grep finds a match; pipefail would spuriously fail.
set -eu

CLUSTER_NAME="${CLUSTER_NAME:-obs06-debug}"
passed=0
failed=0
report=""

skip() { echo "SKIP: $1"; exit 0; }

command -v kind    >/dev/null 2>&1 || skip "kind not installed"
command -v kubectl >/dev/null 2>&1 || skip "kubectl not installed"
command -v curl    >/dev/null 2>&1 || skip "curl not installed"

if ! kubectl --context "kind-${CLUSTER_NAME}" get ns >/dev/null 2>&1; then
  skip "cluster kind-${CLUSTER_NAME} not reachable (did you run 'kind create cluster --name ${CLUSTER_NAME}'?)"
fi
ctx="--context=kind-${CLUSTER_NAME}"

check_scenario() {
  local n="$1"
  local ns="obs-s${n}"
  local svc="prom-s${n}"
  local pod="app-s${n}"
  local lport="$((19090 + n))"
  local name="Scenario ${n}"

  if ! kubectl $ctx -n "$ns" get svc "$svc" >/dev/null 2>&1; then
    report+="$name: FAIL (svc $svc en $ns no existe — ¿aplicaste scenarios/$n/?)\n"
    failed=$((failed+1)); return
  fi

  # Esperar pod Prometheus
  if ! kubectl $ctx -n "$ns" wait --for=condition=Ready pod -l app="$svc" --timeout=60s >/dev/null 2>&1; then
    report+="$name: FAIL (Prometheus pod no Ready)\n"
    failed=$((failed+1)); return
  fi

  # Esperar pod app
  kubectl $ctx -n "$ns" wait --for=condition=Ready pod -l app="$pod" --timeout=60s >/dev/null 2>&1 || true

  kubectl $ctx -n "$ns" port-forward "svc/$svc" "${lport}:9090" >/dev/null 2>&1 &
  local pf=$!
  sleep 4

  # Esperar a que haya al menos un scrape ciclo
  sleep 12

  local resp
  resp=$(curl -s --max-time 5 "localhost:${lport}/api/v1/targets?state=active" || echo "")
  kill $pf 2>/dev/null || true
  wait $pf 2>/dev/null || true

  if echo "$resp" | grep -q "\"pod\":\"${pod}"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL (target ${pod} no activo)\n"
    failed=$((failed+1))
  fi
}

for n in 1 2 3 4; do
  check_scenario "$n"
done

total=$((passed+failed))
echo -e "\n=== obs-06-02 validate ==="
echo -e "$report"
echo "Resultado: $passed/$total OK"
[ "$failed" -eq 0 ]
