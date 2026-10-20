#!/usr/bin/env bash
# Install upstream Argo CD on the hub cluster.
# Idempotent: safe to re-run.
set -euo pipefail

CTX="${HUB_CONTEXT:-kind-argo-hub}"

kubectl --context "$CTX" get ns argocd >/dev/null 2>&1 \
  || kubectl --context "$CTX" create ns argocd

kubectl --context "$CTX" -n argocd apply \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for argocd-server deployment..."
kubectl --context "$CTX" -n argocd rollout status deploy/argocd-server --timeout=180s
echo "Argo CD installed on $CTX."
