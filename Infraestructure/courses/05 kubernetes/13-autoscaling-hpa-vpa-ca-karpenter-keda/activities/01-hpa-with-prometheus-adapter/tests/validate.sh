#!/usr/bin/env bash
# Validate k8s-13-01: HPA scaled above 1 replica under synthetic load.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks use
# pipelines with `grep -q` or `kubectl ... | grep ...` which can produce
# SIGPIPE (exit 141) on the upstream command when grep finds a match early.
# pipefail would spuriously mark those as failures.

CTX="${CTX:-kind-k8s-13-01}"
NS="${NS:-default}"
HPA_NAME="${HPA_NAME:-web}"
DEPLOY_NAME="${DEPLOY_NAME:-web}"

passed=0
failed=0
report=""

check_cluster() {
  local name="Cluster reachable (context $CTX)"
  if kubectl --context "$CTX" cluster-info >/dev/null 2>&1; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — kubectl cannot reach the cluster\n"
    failed=$((failed+1))
  fi
}

check_metrics_server() {
  local name="metrics-server serving (kubectl top nodes)"
  if kubectl --context "$CTX" top nodes >/dev/null 2>&1; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — kubectl top nodes failed; metrics-server not ready\n"
    failed=$((failed+1))
  fi
}

check_deployment() {
  local name="Deployment $DEPLOY_NAME has >=2 ready replicas"
  local ready
  ready="$(kubectl --context "$CTX" -n "$NS" get deploy "$DEPLOY_NAME" \
             -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  ready="${ready:-0}"
  if [ "$ready" -ge 2 ] 2>/dev/null; then
    report+="$name: OK (readyReplicas=$ready)\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — readyReplicas='$ready' (need >=2; generate more load and wait ~2 min)\n"
    failed=$((failed+1))
  fi
}

check_hpa_scaled() {
  local name="HPA $HPA_NAME scaled above 1 replica"
  local hpa_json
  hpa_json="$(kubectl --context "$CTX" -n "$NS" get hpa "$HPA_NAME" -o json 2>/dev/null)"
  if [ -z "$hpa_json" ]; then
    report+="$name: FAIL — HPA $HPA_NAME not found\n"
    failed=$((failed+1))
    return
  fi

  local current desired
  current="$(printf '%s' "$hpa_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("status",{}).get("currentReplicas", 0))' 2>/dev/null)"
  desired="$(printf '%s' "$hpa_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("status",{}).get("desiredReplicas", 0))' 2>/dev/null)"
  current="${current:-0}"
  desired="${desired:-0}"

  if [ "$current" -gt 1 ] 2>/dev/null; then
    report+="$name: OK (currentReplicas=$current, desiredReplicas=$desired)\n"
    passed=$((passed+1))
  else
    report+="$name: FAIL — currentReplicas=$current, desiredReplicas=$desired. "
    report+="Run the load generator for ~2 min and retry.\n"
    failed=$((failed+1))
  fi
}

check_hpa_active() {
  local name="HPA ScalingActive condition is True"
  local active
  active="$(kubectl --context "$CTX" -n "$NS" get hpa "$HPA_NAME" \
             -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].status}' 2>/dev/null)"
  if [ "$active" = "True" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — ScalingActive='$active' (check 'kubectl describe hpa $HPA_NAME')\n"
    failed=$((failed+1))
  fi
}

echo "== Validating k8s-13-01 on context $CTX, namespace $NS =="

check_cluster
check_metrics_server
check_deployment
check_hpa_active
check_hpa_scaled

echo
printf "%b" "$report"
echo

total=$((passed + failed))
if [ "$failed" -eq 0 ]; then
  echo "RESULT: OK — $passed/$total checks passed. HPA scaled under load."
  exit 0
else
  echo "RESULT: FAIL — $passed/$total checks passed, $failed failing."
  exit 1
fi
