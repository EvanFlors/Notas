#!/usr/bin/env bash
# Alternative: register the spoke using the argocd CLI. Produces the same Secret as the
# declarative path, but outside of Git — use only to explore, not to operate.
set -euo pipefail

HUB_CTX="${HUB_CONTEXT:-kind-argo-hub}"
SPOKE_CTX="${SPOKE_CONTEXT:-kind-argo-spoke}"

command -v argocd >/dev/null || { echo "argocd CLI not installed"; exit 2; }

# Port-forward in background to log in
kubectl --context "$HUB_CTX" -n argocd port-forward svc/argocd-server 8080:443 >/dev/null 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT
sleep 3

PW="$(kubectl --context "$HUB_CTX" -n argocd get secret argocd-initial-admin-secret \
      -o jsonpath='{.data.password}' | base64 -d)"
argocd login localhost:8080 --username admin --password "$PW" --insecure

argocd cluster add "$SPOKE_CTX" --name spoke --yes
argocd cluster list
