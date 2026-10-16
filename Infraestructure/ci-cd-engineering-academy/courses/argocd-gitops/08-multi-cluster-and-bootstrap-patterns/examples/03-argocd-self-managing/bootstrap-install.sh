#!/usr/bin/env bash
# First-time imperative install of Argo CD. After this, apply application.yaml so Argo CD
# starts managing its own installation. Pin ARGOCD_TAG for reproducibility.
set -euo pipefail

CTX="${CONTEXT:-$(kubectl config current-context)}"
ARGOCD_TAG="${ARGOCD_TAG:-v2.13.1}"

kubectl --context "$CTX" get ns argocd >/dev/null 2>&1 \
  || kubectl --context "$CTX" create ns argocd

kubectl --context "$CTX" -n argocd apply \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_TAG}/manifests/install.yaml"

kubectl --context "$CTX" -n argocd rollout status deploy/argocd-server --timeout=180s

echo "Argo CD ${ARGOCD_TAG} installed on ${CTX}."
echo "Next: kubectl --context ${CTX} apply -f application.yaml"
