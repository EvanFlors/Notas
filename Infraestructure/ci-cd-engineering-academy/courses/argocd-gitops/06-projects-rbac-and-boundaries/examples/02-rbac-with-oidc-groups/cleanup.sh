#!/usr/bin/env bash
# Restore a minimal argocd-rbac-cm (default readonly, no custom policies).
# Does NOT remove the ConfigMap itself (argocd-server expects it to exist).
set -eu

NS=argocd
if ! command -v kubectl >/dev/null 2>&1 || ! kubectl config current-context >/dev/null 2>&1; then
  echo "SKIP: no kubectl / no current context."
  exit 0
fi

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-rbac-cm
    app.kubernetes.io/part-of: argocd
data:
  policy.default: role:readonly
  policy.csv: ""
EOF

echo "argocd-rbac-cm reset to default readonly."
