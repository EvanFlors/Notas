#!/usr/bin/env bash
# validate.sh — Automated checks for the Kubernetes exam operative exercise.
# Exits non-zero on first failure. Prints a human-readable summary.
set -u

NS="exam"
DEPLOY="http-echo"
SVC="http-echo"
PDB="http-echo"
NETPOL_DENY="default-deny-all"
NETPOL_ALLOW="allow-client-to-echo"
CLIENT_OK="curl-client"
CLIENT_BAD="curl-unauth"

pass=0
fail=0
report() {
  local status="$1"; shift
  if [[ "$status" == "ok" ]]; then
    echo "  [ok] $*"
    pass=$((pass+1))
  else
    echo "  [FAIL] $*"
    fail=$((fail+1))
  fi
}

echo "== 1. Namespace =="
kubectl get ns "$NS" >/dev/null 2>&1 \
  && report ok "namespace $NS exists" \
  || report fail "namespace $NS missing"

echo "== 2. Deployment ready =="
ready=$(kubectl -n "$NS" get deploy "$DEPLOY" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
desired=$(kubectl -n "$NS" get deploy "$DEPLOY" -o jsonpath='{.spec.replicas}' 2>/dev/null)
if [[ "${ready:-0}" == "3" && "$desired" == "3" ]]; then
  report ok "deployment $DEPLOY has 3/3 ready"
else
  report fail "deployment $DEPLOY not 3/3 ready (ready=$ready desired=$desired)"
fi

echo "== 3. Three distinct probes =="
for probe in startupProbe readinessProbe livenessProbe; do
  val=$(kubectl -n "$NS" get deploy "$DEPLOY" \
    -o jsonpath="{.spec.template.spec.containers[0].$probe}" 2>/dev/null)
  [[ -n "$val" ]] \
    && report ok "$probe defined" \
    || report fail "$probe missing"
done

echo "== 4. PDB =="
minavail=$(kubectl -n "$NS" get pdb "$PDB" -o jsonpath='{.spec.minAvailable}' 2>/dev/null)
[[ "$minavail" == "2" ]] \
  && report ok "PDB $PDB minAvailable=2" \
  || report fail "PDB $PDB missing or wrong (minAvailable=$minavail)"

echo "== 5. NetworkPolicies =="
kubectl -n "$NS" get netpol "$NETPOL_DENY" >/dev/null 2>&1 \
  && report ok "$NETPOL_DENY present" \
  || report fail "$NETPOL_DENY missing"
kubectl -n "$NS" get netpol "$NETPOL_ALLOW" >/dev/null 2>&1 \
  && report ok "$NETPOL_ALLOW present" \
  || report fail "$NETPOL_ALLOW missing"

echo "== 6. Authorized client can reach the service =="
if kubectl -n "$NS" exec "$CLIENT_OK" -- \
     curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
     "http://$SVC.$NS.svc.cluster.local/" | grep -q '^200$'; then
  report ok "$CLIENT_OK gets 200"
else
  report fail "$CLIENT_OK cannot reach $SVC (expected 200)"
fi

echo "== 7. Unauthorized client is blocked =="
if kubectl -n "$NS" exec "$CLIENT_BAD" -- \
     curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
     "http://$SVC.$NS.svc.cluster.local/" 2>/dev/null | grep -q '^200$'; then
  report fail "$CLIENT_BAD reached $SVC (NetworkPolicy not enforcing)"
else
  report ok "$CLIENT_BAD blocked (timeout or non-200)"
fi

echo "== 8. Image pinning =="
img=$(kubectl -n "$NS" get deploy "$DEPLOY" \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
if [[ "$img" == *":latest" || -z "$img" ]]; then
  report fail "image not pinned (image=$img)"
else
  report ok "image pinned: $img"
fi

echo "== 9. runAsNonRoot =="
nonroot=$(kubectl -n "$NS" get deploy "$DEPLOY" \
  -o jsonpath='{.spec.template.spec.containers[0].securityContext.runAsNonRoot}' 2>/dev/null)
[[ "$nonroot" == "true" ]] \
  && report ok "runAsNonRoot=true" \
  || report fail "runAsNonRoot missing or false"

echo
echo "Summary: $pass passed, $fail failed."
[[ "$fail" -eq 0 ]] && exit 0 || exit 1
