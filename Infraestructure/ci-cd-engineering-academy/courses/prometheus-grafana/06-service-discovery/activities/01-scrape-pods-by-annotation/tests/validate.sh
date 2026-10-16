#!/usr/bin/env bash
# Validate obs-06-01-scrape-pods-by-annotation.
#
# Note: pipefail is intentionally NOT set because several checks use
# `curl ... | grep -q ...`; grep closes the pipe early and SIGPIPEs the
# upstream process, which pipefail would spuriously flag as failure.
set -eu

CLUSTER_NAME="${CLUSTER_NAME:-obs06-lab}"
NS_MON=monitoring
NS_DEMO=demo
passed=0
failed=0
report=""

skip() {
  echo "SKIP: $1"
  exit 0
}

command -v kind    >/dev/null 2>&1 || skip "kind not installed"
command -v kubectl >/dev/null 2>&1 || skip "kubectl not installed"
command -v curl    >/dev/null 2>&1 || skip "curl not installed"

# Must be able to talk to a cluster (user is expected to have created it)
if ! kubectl --context "kind-${CLUSTER_NAME}" get ns >/dev/null 2>&1; then
  skip "cluster kind-${CLUSTER_NAME} not reachable (did you run 'kind create cluster --name ${CLUSTER_NAME}'?)"
fi

ctx="--context=kind-${CLUSTER_NAME}"

check_prom_ready() {
  local name="Prometheus pod Ready"
  if kubectl $ctx -n "$NS_MON" wait --for=condition=Ready pod -l app=prometheus --timeout=60s >/dev/null 2>&1; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — pod no Ready\n"; failed=$((failed+1))
  fi
}

check_targets() {
  local name="Targets filtered by annotation"
  kubectl $ctx -n "$NS_MON" port-forward svc/prometheus 19090:9090 >/dev/null 2>&1 &
  local pf=$!
  sleep 3

  local targets
  targets=$(curl -s --max-time 5 localhost:19090/api/v1/targets || echo "")
  kill $pf 2>/dev/null || true
  wait $pf 2>/dev/null || true

  local has_ann has_un
  echo "$targets" | grep -q "app-annotated"   && has_ann=1 || has_ann=0
  echo "$targets" | grep -q "app-unannotated" && has_un=1  || has_un=0

  if [ "$has_ann" = "1" ] && [ "$has_un" = "0" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — annotated=$has_ann unannotated=$has_un (esperado 1 / 0)\n"
    failed=$((failed+1))
  fi
}

check_labels() {
  local name="Labels promovidos (namespace, pod)"
  kubectl $ctx -n "$NS_MON" port-forward svc/prometheus 19090:9090 >/dev/null 2>&1 &
  local pf=$!
  sleep 3

  local out
  out=$(curl -s --max-time 5 'localhost:19090/api/v1/targets' || echo "")
  kill $pf 2>/dev/null || true
  wait $pf 2>/dev/null || true

  local ok_ns ok_pod
  echo "$out" | grep -q '"namespace":"demo"' && ok_ns=1  || ok_ns=0
  echo "$out" | grep -q '"pod":"app-annotated' && ok_pod=1 || ok_pod=0

  if [ "$ok_ns" = "1" ] && [ "$ok_pod" = "1" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — ns=$ok_ns pod=$ok_pod\n"; failed=$((failed+1))
  fi
}

check_prom_ready
check_targets
check_labels

total=$((passed+failed))
echo -e "\n=== obs-06-01 validate ==="
echo -e "$report"
echo "Resultado: $passed/$total OK"
[ "$failed" -eq 0 ]
