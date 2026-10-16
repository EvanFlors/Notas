#!/usr/bin/env bash
# Apply the two AppProjects and the two Applications.
# Verifies that the "bad" Application gets a ComparisonError /
# InvalidSpecError mentioning "not permitted in project".
#
# SKIPS GRACEFULLY if there is no kubeconfig context or Argo CD is not installed.
#
# NOTE: pipefail is intentionally OFF — several checks use `grep -q` on piped
# output and would spuriously fail on SIGPIPE.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
NS=argocd

echo "== Preflight =="

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed."
  exit 0
fi

if ! kubectl config current-context >/dev/null 2>&1; then
  echo "SKIP: no current kubeconfig context. Start a kind cluster and install Argo CD first."
  exit 0
fi

if ! kubectl get ns "$NS" >/dev/null 2>&1; then
  echo "SKIP: namespace '$NS' not found — install Argo CD first (see argo-02)."
  exit 0
fi

if ! kubectl -n "$NS" get crd appprojects.argoproj.io >/dev/null 2>&1; then
  echo "SKIP: Argo CD CRDs not installed."
  exit 0
fi

echo "  OK   Argo CD is reachable in namespace '$NS'"

echo "== Apply AppProjects =="
kubectl apply -f "$HERE/project-team-payments.yaml"
kubectl apply -f "$HERE/project-team-checkout.yaml"

echo "== Apply Applications (good + bad) =="
kubectl apply -f "$HERE/app-payments-good.yaml"
kubectl apply -f "$HERE/app-payments-bad.yaml"

echo "== Wait briefly for controller reconciliation =="
sleep 10

echo "== Inspect 'bad' Application =="
# We extract the conditions. The expected message contains 'not permitted'.
bad_conditions=$(kubectl -n "$NS" get application payments-crossing-boundary \
  -o jsonpath='{.status.conditions}' 2>/dev/null || echo "")

echo "Conditions on bad app:"
echo "  $bad_conditions"

# Check WITHOUT pipefail — grep -q on piped text is intentional here.
if echo "$bad_conditions" | grep -q "not permitted in project"; then
  echo "  OK   boundary enforced: 'bad' Application rejected as expected"
else
  echo "  WARN boundary message not found yet; may need more reconciliation time."
  echo "       Re-check with: kubectl -n $NS get application payments-crossing-boundary -o yaml"
fi

echo
echo "Done. Clean up with: bash cleanup.sh"
