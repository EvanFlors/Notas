#!/usr/bin/env bash
# Validate k8s-03-02-rollout-and-rollback.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks use
# patterns like `kubectl ... | grep -q ...`; if grep matches early it can
# trigger SIGPIPE (exit 141) on the upstream kubectl command, and pipefail
# would promote that to a failure of the whole pipeline — a false negative.

NS="${NS:-k8s-03-02}"
NAME="rollout-demo"
WANTED_IMAGE="nginx:1.26-alpine"
MIN_REVISIONS=4

passed=0
failed=0
report=""

ok()  { report+="  OK   $1\n"; passed=$((passed+1)); }
bad() { report+="  FAIL $1\n"; failed=$((failed+1)); }

# --- Preflight ---
if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: 'kubectl' no está instalado."
  exit 0
fi
if ! kubectl config current-context >/dev/null 2>&1; then
  echo "SKIP: no hay contexto activo en kubeconfig."
  exit 0
fi
if ! kubectl get --raw=/readyz --request-timeout=10s >/dev/null 2>&1; then
  echo "SKIP: no hay cluster accesible (/readyz no responde)."
  exit 0
fi

echo "== Validando namespace=$NS deployment=$NAME =="

# --- Namespace & Deployment presence ---
if ! kubectl get ns "$NS" >/dev/null 2>&1; then
  bad "namespace '$NS' no existe"
  echo -e "$report"; echo "RESULT: FAIL"; exit 1
fi
ok "namespace '$NS' existe"

if ! kubectl -n "$NS" get deployment "$NAME" >/dev/null 2>&1; then
  bad "deployment '$NAME' no existe en namespace '$NS'"
  echo -e "$report"; echo "RESULT: FAIL"; exit 1
fi
ok "deployment '$NAME' existe"

# --- Image is the rollback target ---
image="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)"
if [ "$image" = "$WANTED_IMAGE" ]; then
  ok "image actual = $WANTED_IMAGE (consistente con rollback a revisión 2)"
else
  bad "image actual = '$image' (esperado '$WANTED_IMAGE')"
fi

# --- Ready replicas ---
ready="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
desired="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.status.replicas}' 2>/dev/null)"
if [ "$ready" = "3" ] && [ "$desired" = "3" ]; then
  ok "status: ready=3 desired=3"
else
  bad "status: ready='$ready' desired='$desired' (esperado 3/3)"
fi

# --- Rollout history has >= MIN_REVISIONS revisions ---
# `rollout history` output example:
#   deployment.apps/rollout-demo
#   REVISION  CHANGE-CAUSE
#   1         ...
#   3         ...
#   4         ...
#   5         ...
rev_count="$(kubectl -n "$NS" rollout history deployment/"$NAME" 2>/dev/null \
             | awk 'NR>2 && NF>0 {c++} END{print c+0}')"
if [ "${rev_count:-0}" -ge "$MIN_REVISIONS" ]; then
  ok "rollout history con $rev_count revisiones (>= $MIN_REVISIONS)"
else
  bad "rollout history con $rev_count revisiones (esperado >= $MIN_REVISIONS)"
fi

# --- At least 2 ReplicaSets (evidencia de rollouts) ---
rs_count="$(kubectl -n "$NS" get rs -l app="$NAME" -o name 2>/dev/null | wc -l | tr -d ' ')"
if [ "${rs_count:-0}" -ge 2 ]; then
  ok "replicaSets observados = $rs_count"
else
  bad "replicaSets = $rs_count (esperado >= 2)"
fi

# --- 3 Pods Running ---
running="$(kubectl -n "$NS" get pods -l app="$NAME" --field-selector=status.phase=Running -o name 2>/dev/null | wc -l | tr -d ' ')"
[ "${running:-0}" = "3" ] && ok "3 Pods Running" || bad "Pods Running = $running (esperado 3)"

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
