#!/usr/bin/env bash
# Validate the two AppProjects and the two Applications of argo-06-01.
#
# Note: pipefail is intentionally OFF because several checks use `grep -q`
# over piped output and would spuriously fail on SIGPIPE / 141.
set -eu

NS=argocd
fail=0

ok()   { echo "  OK   $*"; }
bad()  { echo "  FAIL $*"; fail=$((fail+1)); }

echo "== Preflight =="

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed."
  exit 0
fi
if ! kubectl config current-context >/dev/null 2>&1; then
  echo "SKIP: no current kubeconfig context."
  exit 0
fi
if ! kubectl get ns "$NS" >/dev/null 2>&1; then
  echo "SKIP: namespace '$NS' not found — install Argo CD first."
  exit 0
fi
if ! kubectl -n "$NS" get crd appprojects.argoproj.io >/dev/null 2>&1; then
  echo "SKIP: Argo CD CRDs not installed."
  exit 0
fi
ok "Argo CD reachable"

echo "== AppProjects =="

for proj in team-payments team-checkout; do
  if kubectl -n "$NS" get appproject "$proj" >/dev/null 2>&1; then
    ok "AppProject '$proj' exists"
  else
    bad "AppProject '$proj' missing — apply the starter manifests first"
    continue
  fi

  repos=$(kubectl -n "$NS" get appproject "$proj" -o jsonpath='{.spec.sourceRepos}')
  if echo "$repos" | grep -q '"\*"'; then
    bad "'$proj'.sourceRepos still contains '*' (wildcard). Pin to a specific repo."
  else
    ok  "'$proj'.sourceRepos is scoped"
  fi
done

ns_payments=$(kubectl -n "$NS" get appproject team-payments \
  -o jsonpath='{.spec.destinations[0].namespace}' 2>/dev/null || echo "")
if [ "$ns_payments" = "payments-*" ]; then
  ok "team-payments.destinations[0].namespace = payments-*"
else
  bad "team-payments.destinations[0].namespace = '$ns_payments' (expected 'payments-*')"
fi

ns_checkout=$(kubectl -n "$NS" get appproject team-checkout \
  -o jsonpath='{.spec.destinations[0].namespace}' 2>/dev/null || echo "")
if [ "$ns_checkout" = "checkout-*" ]; then
  ok "team-checkout.destinations[0].namespace = checkout-*"
else
  bad "team-checkout.destinations[0].namespace = '$ns_checkout' (expected 'checkout-*')"
fi

# team-payments must list Namespace in clusterResourceWhitelist
cwh=$(kubectl -n "$NS" get appproject team-payments \
  -o jsonpath='{.spec.clusterResourceWhitelist}' 2>/dev/null || echo "")
if echo "$cwh" | grep -q 'Namespace'; then
  ok "team-payments.clusterResourceWhitelist allows Namespace"
else
  bad "team-payments.clusterResourceWhitelist does NOT allow Namespace"
fi

# team-payments must blacklist ResourceQuota
bwh=$(kubectl -n "$NS" get appproject team-payments \
  -o jsonpath='{.spec.namespaceResourceBlacklist}' 2>/dev/null || echo "")
if echo "$bwh" | grep -q 'ResourceQuota'; then
  ok "team-payments.namespaceResourceBlacklist contains ResourceQuota"
else
  bad "team-payments.namespaceResourceBlacklist does NOT contain ResourceQuota"
fi

echo "== Applications =="

if kubectl -n "$NS" get application payments-good >/dev/null 2>&1; then
  ok "Application 'payments-good' exists"
  proj=$(kubectl -n "$NS" get application payments-good -o jsonpath='{.spec.project}')
  if [ "$proj" = "team-payments" ]; then
    ok "payments-good belongs to project team-payments"
  else
    bad "payments-good project = '$proj' (expected team-payments)"
  fi
else
  bad "Application 'payments-good' missing"
fi

if kubectl -n "$NS" get application checkout-crossing >/dev/null 2>&1; then
  ok "Application 'checkout-crossing' exists"

  # Wait a few seconds for the controller to evaluate.
  for _ in 1 2 3 4 5 6; do
    conds=$(kubectl -n "$NS" get application checkout-crossing \
      -o jsonpath='{.status.conditions}' 2>/dev/null || echo "")
    if echo "$conds" | grep -q 'not permitted'; then
      break
    fi
    sleep 5
  done

  if echo "$conds" | grep -q 'not permitted'; then
    ok "checkout-crossing was rejected with 'not permitted' — boundary ENFORCED"
  else
    bad "checkout-crossing has no 'not permitted' condition yet (got: $conds)"
  fi
else
  bad "Application 'checkout-crossing' missing"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: all checks passed. Boundaries work as expected."
exit 0
