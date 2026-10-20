#!/usr/bin/env bash
# Bootstrap for argo-11-01-harden-argocd-install.
# - Verifies kubectl + active context.
# - Installs Argo CD stable manifest into ns 'argocd' (if not already present).
# - Writes placeholder files in <BASE>/work/ for the 7 hardening controls.
set -euo pipefail

BASE="${1:-/tmp/argo-11-01}"
if [ -e "$BASE" ]; then
  echo "Removing previous $BASE"
  rm -rf "$BASE"
fi

WORK="$BASE/work"
mkdir -p "$WORK"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed." >&2
  exit 0
fi
if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  echo "SKIP: no active kube context. Try: kind create cluster --name argo-11-01" >&2
  exit 0
fi

echo "== Ensuring namespace 'argocd' (NO PSA labels — you will add them) =="
kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -

if ! kubectl -n argocd get deploy argocd-server >/dev/null 2>&1; then
  echo "== Installing Argo CD stable manifests =="
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  echo "== Waiting for argocd-server =="
  kubectl -n argocd rollout status deploy/argocd-server --timeout=300s || true
else
  echo "== Argo CD already installed, reusing =="
fi

# ------- placeholder files for the student -------

cat > "$WORK/argocd-cm.yaml" <<'EOF'
# TODO (Control 1): disable local admin.
# Hint: data.admin.enabled: "false"
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels: { app.kubernetes.io/part-of: argocd }
data:
  url: https://argocd.example.com
  admin.enabled: "true"   # <-- change this
EOF

cat > "$WORK/argocd-cmd-params-cm.yaml" <<'EOF'
# TODO (Control 2): force HTTPS by setting server.insecure to "false".
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
  labels: { app.kubernetes.io/part-of: argocd }
data:
  server.insecure: "true"   # <-- change this
EOF

cat > "$WORK/argocd-rbac-cm.yaml" <<'EOF'
# TODO (Control 6): deny-by-default policy with at least one role (p,…) and one binding (g,…).
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
  labels: { app.kubernetes.io/part-of: argocd }
data:
  policy.default: role:readonly   # <-- make it ""
  scopes: '[groups]'
  policy.csv: |
    # placeholder: write real roles + bindings here
EOF

cat > "$WORK/networkpolicy.yaml" <<'EOF'
# TODO (Control 4): default-deny + egress DNS to kube-system (and optionally git/apiserver rules).
# Minimum: a default-deny NetworkPolicy on podSelector:{} AND one NP allowing egress UDP/53
# to namespaceSelector matching kube-system.
# Write the two (or more) NetworkPolicies here.
EOF

cat > "$WORK/namespace-labels.sh" <<'EOF'
#!/usr/bin/env bash
# TODO (Control 3): label namespace 'argocd' with Pod Security Admission = restricted.
# Hint:
#   kubectl label ns argocd \
#     pod-security.kubernetes.io/enforce=restricted \
#     pod-security.kubernetes.io/audit=restricted \
#     pod-security.kubernetes.io/warn=restricted --overwrite
EOF
chmod +x "$WORK/namespace-labels.sh"

cat > "$WORK/rotate-secretkey.sh" <<'EOF'
#!/usr/bin/env bash
# TODO (Control 5): rotate server.secretkey.
# One way: remove the key from argocd-secret and bounce the server; it will regenerate.
#   kubectl -n argocd patch secret argocd-secret --type json \
#     -p '[{"op":"remove","path":"/data/server.secretkey"}]'
#   kubectl -n argocd rollout restart deploy/argocd-server
# Then capture the new value and persist a snapshot:
#   kubectl -n argocd get secret argocd-secret -o jsonpath='{.data.server\.secretkey}' > /tmp/argo-11-01/rotated.b64
EOF
chmod +x "$WORK/rotate-secretkey.sh"

# Snapshot of the ORIGINAL server.secretkey (so validator can compare post-rotation).
if kubectl -n argocd get secret argocd-secret >/dev/null 2>&1; then
  kubectl -n argocd get secret argocd-secret \
    -o jsonpath='{.data.server\.secretkey}' > "$BASE/original.secretkey.b64" 2>/dev/null || true
fi

echo
echo "Bootstrap OK."
echo "Edit files in $WORK/ then run:"
echo "  bash courses/argocd-gitops/11-internals-and-security/activities/01-harden-argocd-install/tests/validate.sh"
