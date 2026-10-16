#!/usr/bin/env bash
# Validate the PR-previews lab end-state.
#
# Note: no `set -o pipefail` on purpose — `grep -q` closes upstream which would
# spuriously mark the previous pipe stage as failed under pipefail.

CLUSTER="${CLUSTER:-argo-12-ex}"
passed=0
failed=0
report=""

check() {
  local name="$1" ok="$2" hint="$3"
  if [ "$ok" -eq 1 ]; then
    report+="OK   — $name\n"; passed=$((passed+1))
  else
    report+="FAIL — $name ($hint)\n"; failed=$((failed+1))
  fi
}

# 1. kind cluster exists
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  check "kind cluster '$CLUSTER' exists" 1 ""
else
  check "kind cluster '$CLUSTER' exists" 0 "run bootstrap.sh first"
fi

# Switch context if available
if kubectl config get-contexts "kind-$CLUSTER" >/dev/null 2>&1; then
  kubectl config use-context "kind-$CLUSTER" >/dev/null
fi

# 2. argocd namespace + core deployments ready
if kubectl -n argocd get deploy argocd-server >/dev/null 2>&1; then
  check "argocd namespace + argocd-server present" 1 ""
else
  check "argocd namespace + argocd-server present" 0 "argocd no instalado"
fi

ready=$(kubectl -n argocd get deploy argocd-applicationset-controller -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [ "${ready:-0}" -ge 1 ]; then
  check "applicationset-controller Ready" 1 ""
else
  check "applicationset-controller Ready" 0 "ready=$ready"
fi

# 3. ApplicationSet 'previews' exists
if kubectl -n argocd get applicationset previews >/dev/null 2>&1; then
  check "ApplicationSet 'previews' exists" 1 ""
else
  check "ApplicationSet 'previews' exists" 0 "aplica starter/appset.yaml"
fi

# 4. AppProject 'previews' exists
if kubectl -n argocd get appproject previews >/dev/null 2>&1; then
  check "AppProject 'previews' exists" 1 ""
else
  check "AppProject 'previews' exists" 0 "aplica starter/project.yaml"
fi

# 5. End-state: no leftover pr-* namespaces (ciclo abierto y cerrado completamente)
leftover=$(kubectl get ns -o name 2>/dev/null | grep -E 'namespace/pr-' || true)
if [ -z "$leftover" ]; then
  check "sin namespaces 'pr-*' residuales" 1 ""
else
  check "sin namespaces 'pr-*' residuales" 0 "quedan: $leftover (ejecuta ./pr-close.sh N para cada uno)"
fi

# 6. End-state: no leftover preview Applications
leftover_apps=$(kubectl -n argocd get applications -o name 2>/dev/null | grep -E 'application.argoproj.io/preview-pr-' || true)
if [ -z "$leftover_apps" ]; then
  check "sin Applications 'preview-pr-*' residuales" 1 ""
else
  check "sin Applications 'preview-pr-*' residuales" 0 "quedan: $leftover_apps"
fi

echo "== Validando lab PR-previews (cluster=$CLUSTER) =="
echo
printf "%b" "$report"
echo
echo "RESULT: $passed OK, $failed FAIL."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
