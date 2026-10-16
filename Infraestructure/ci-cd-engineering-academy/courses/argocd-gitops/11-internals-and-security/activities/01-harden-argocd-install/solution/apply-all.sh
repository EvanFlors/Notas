#!/usr/bin/env bash
# Reference solution: apply all 7 hardening controls.
# Assumes bootstrap.sh already ran and left /tmp/argo-11-01/original.secretkey.b64.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== Control 3: PSA restricted on ns argocd =="
kubectl label ns argocd \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted \
  --overwrite

echo "== Controls 1, 2, 6: apply ConfigMaps =="
kubectl apply -f "$DIR/argocd-cm.yaml"
kubectl apply -f "$DIR/argocd-cmd-params-cm.yaml"
kubectl apply -f "$DIR/argocd-rbac-cm.yaml"

echo "== Control 4: NetworkPolicies =="
kubectl apply -f "$DIR/networkpolicy.yaml"

echo "== Control 5: rotate server.secretkey =="
kubectl -n argocd patch secret argocd-secret --type json \
  -p '[{"op":"remove","path":"/data/server.secretkey"}]' 2>/dev/null || true
kubectl -n argocd rollout restart deploy/argocd-server
kubectl -n argocd rollout status deploy/argocd-server --timeout=120s

echo "== Control 7: ensure no direct cluster-admin binding to the controller SA =="
# If a cluster-admin binding exists for the controller SA, we patch it out.
# (Argo CD stable manifests use a dedicated ClusterRole 'argocd-application-controller'
#  that is NOT cluster-admin, so this is usually a no-op.)
kubectl get clusterrolebindings -o json \
  | jq -r '.items[] | select(.roleRef.name=="cluster-admin")
        | select(.subjects // [] | any(.kind=="ServiceAccount" and .name=="argocd-application-controller" and .namespace=="argocd"))
        | .metadata.name' \
  | while read -r name; do
      [ -n "$name" ] && kubectl delete clusterrolebinding "$name"
    done

echo "OK: solution applied."
