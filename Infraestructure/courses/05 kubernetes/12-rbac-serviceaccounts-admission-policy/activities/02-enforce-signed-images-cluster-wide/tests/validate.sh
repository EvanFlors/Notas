#!/usr/bin/env bash
# Validator for k8s-12-02-enforce-signed-images-cluster-wide.
# Not using `set -o pipefail` — grep -q + long producers can SIGPIPE.
set -u

BASE="${1:-${BASE_DIR:-/tmp/k8s-12-02}}"
CTX="kind-k8s-12-02"
POLICY="require-signed-images"
TEST_NS="signed-images-test"

pass=0
fail=0
report=""

ok()   { report+="  OK   — $1\n"; pass=$((pass+1)); }
bad()  { report+="  FAIL — $1\n"; fail=$((fail+1)); }
skip() { report+="  SKIP — $1\n"; }

echo "== Validating Kyverno signed-images policy on $CTX =="

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl not in PATH" >&2
  exit 2
fi

if ! kubectl --context "$CTX" cluster-info >/dev/null 2>&1; then
  bad "cluster context '$CTX' not reachable (run starter/bootstrap.sh first)"
  echo
  printf "%b" "$report"
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi

# Kyverno namespace + pods ready
if kubectl --context "$CTX" get ns kyverno >/dev/null 2>&1; then
  ok "namespace 'kyverno' exists"
else
  bad "namespace 'kyverno' not found (install Kyverno first)"
  echo
  printf "%b" "$report"
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi

running="$(kubectl --context "$CTX" -n kyverno get pods --no-headers 2>/dev/null \
  | awk '$3=="Running"{c++} END{print c+0}')"
if [ "${running:-0}" -ge 1 ]; then
  ok "kyverno has $running pod(s) Running"
else
  bad "no Running pods in namespace kyverno"
fi

# CRD present
if kubectl --context "$CTX" get crd clusterpolicies.kyverno.io >/dev/null 2>&1; then
  ok "CRD clusterpolicies.kyverno.io exists"
else
  bad "CRD clusterpolicies.kyverno.io missing"
fi

# ClusterPolicy present
if ! kubectl --context "$CTX" get clusterpolicy "$POLICY" >/dev/null 2>&1; then
  bad "ClusterPolicy '$POLICY' not found"
  echo
  printf "%b" "$report"
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
else
  ok "ClusterPolicy '$POLICY' exists"
fi

# Inspect policy with python/yaml-free JSON path
action="$(kubectl --context "$CTX" get clusterpolicy "$POLICY" -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)"
if [ "$action" = "Enforce" ]; then
  ok "spec.validationFailureAction == Enforce"
else
  bad "spec.validationFailureAction should be 'Enforce' (got: '${action:-<unset>}')"
fi

# Check that at least one rule has verifyImages
has_verify="$(kubectl --context "$CTX" get clusterpolicy "$POLICY" -o json 2>/dev/null \
  | python3 -c '
import json, sys
try:
    doc = json.load(sys.stdin)
except Exception:
    print("no"); sys.exit(0)
rules = (doc.get("spec") or {}).get("rules") or []
for r in rules:
    if r.get("verifyImages"):
        print("yes"); sys.exit(0)
print("no")
' 2>/dev/null)"
if [ "$has_verify" = "yes" ]; then
  ok "ClusterPolicy has a rule with verifyImages block"
else
  bad "no rule in ClusterPolicy '$POLICY' contains a verifyImages block"
fi

# Policy Ready condition
ready="$(kubectl --context "$CTX" get clusterpolicy "$POLICY" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
if [ "$ready" = "True" ]; then
  ok "ClusterPolicy status Ready=True"
else
  skip "ClusterPolicy Ready condition is '${ready:-<unknown>}' (may still be reconciling)"
fi

# Attempt to create a Pod with a matching unsigned image — must be denied.
# Use a dedicated namespace so matchResources selectors (if any) can't exclude it.
kubectl --context "$CTX" get ns "$TEST_NS" >/dev/null 2>&1 || \
  kubectl --context "$CTX" create ns "$TEST_NS" >/dev/null 2>&1 || true

tmp_out="$(mktemp -t validate-signed-images-XXXX)"
trap 'rm -f "$tmp_out"' EXIT

# Use --dry-run=server so the webhook actually fires, no real pod is left behind.
set +e
kubectl --context "$CTX" -n "$TEST_NS" run test-unsigned \
  --image=docker.io/library/nginx:1.27-alpine \
  --dry-run=server --restart=Never -o yaml >"$tmp_out" 2>&1
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  # Rejected — exactly what we want. Check that message mentions the policy or admission block.
  if grep -qiE "require-signed-images|verifyImages|blocked due to the following policies|admission webhook" "$tmp_out"; then
    ok "unsigned Pod creation rejected by admission (webhook message cites the policy)"
  else
    ok "unsigned Pod creation rejected by admission (exit $rc, generic message)"
  fi
else
  bad "unsigned Pod creation was NOT rejected (webhook not enforcing — check policy match + action)"
fi

# Best-effort cleanup of test namespace
kubectl --context "$CTX" delete ns "$TEST_NS" --wait=false >/dev/null 2>&1 || true

echo
printf "%b" "$report"
echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: ALL CHECKS PASS ($pass/$pass)"
  exit 0
else
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi
