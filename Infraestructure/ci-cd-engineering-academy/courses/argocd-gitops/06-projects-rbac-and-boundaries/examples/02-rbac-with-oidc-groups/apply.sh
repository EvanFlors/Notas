#!/usr/bin/env bash
# Apply ONLY the argocd-rbac-cm (safe: pure RBAC CSV).
# Does NOT touch argocd-cm (OIDC snippet is illustrative only).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
NS=argocd

if ! command -v kubectl >/dev/null 2>&1 || ! kubectl config current-context >/dev/null 2>&1; then
  echo "SKIP: no kubectl / no current context."
  exit 0
fi
if ! kubectl get ns "$NS" >/dev/null 2>&1; then
  echo "SKIP: namespace '$NS' not found — install Argo CD first."
  exit 0
fi

# Back up current argocd-rbac-cm (if any) to /tmp for safe restore.
BACKUP=/tmp/argocd-rbac-cm.backup.$(date +%s).yaml
if kubectl -n "$NS" get cm argocd-rbac-cm >/dev/null 2>&1; then
  kubectl -n "$NS" get cm argocd-rbac-cm -o yaml > "$BACKUP"
  echo "  Backed up existing argocd-rbac-cm to $BACKUP"
fi

kubectl apply -f "$HERE/argocd-rbac-cm.yaml"
echo "  OK   argocd-rbac-cm applied."

# argocd-server picks up changes within ~1s (file watcher on CM mount).
echo "Done. Verify with: kubectl -n $NS get cm argocd-rbac-cm -o yaml"
