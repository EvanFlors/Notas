#!/usr/bin/env bash
# bootstrap.sh — materialize a local bootstrap repo + two kind clusters, then apply the
# root ApplicationSet so the hub cluster self-manages Argo CD and the spoke receives a
# demo app.
#
# Flags:
#   --layout-only     Just render the bootstrap repo under /tmp/argo08. No kind, no
#                     kubectl. Useful for smoke-testing on constrained machines and for
#                     CI linting.
#   --spoke-only      Create ONLY the hub cluster; the spoke registration step is
#                     skipped. Half the memory footprint.
#   -h | --help       Show usage.
#
# No `set -o pipefail` because some pipelines use `grep -q` that can SIGPIPE.
set -eu

BASE="${BASE:-/tmp/argo08}"
REPO="$BASE/bootstrap-repo"
HUB="${HUB_CONTEXT:-kind-argo08-hub}"
SPOKE="${SPOKE_CONTEXT:-kind-argo08-spoke}"
ARGOCD_TAG="${ARGOCD_TAG:-v2.13.1}"

LAYOUT_ONLY=0
SPOKE_ONLY=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --layout-only) LAYOUT_ONLY=1; shift ;;
    --spoke-only)  SPOKE_ONLY=1; shift ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

echo "== bootstrap.sh =="
echo "BASE=$BASE  REPO=$REPO  LAYOUT_ONLY=$LAYOUT_ONLY  SPOKE_ONLY=$SPOKE_ONLY"

# ------------------------------------------------------------------------------
# 1) Render the bootstrap repo layout
# ------------------------------------------------------------------------------
mkdir -p "$REPO/bootstrap" "$REPO/projects" "$REPO/apps/guestbook" \
         "$REPO/addons/argo-cd" "$REPO/addons/metrics-server" \
         "$REPO/clusters/spoke"

# Root ApplicationSet — scans addons/* and apps/* and creates one Application per folder.
cat > "$REPO/bootstrap/root.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: bootstrap-root
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - git:
        repoURL: file://$REPO
        revision: HEAD
        directories:
          - path: addons/*
          - path: apps/*
  template:
    metadata:
      name: '{{.path.basename}}'
    spec:
      project: default
      source:
        repoURL: file://$REPO
        targetRevision: HEAD
        path: '{{.path.path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{.path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
EOF

cat > "$REPO/projects/platform.yaml" <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform
  namespace: argocd
spec:
  description: Platform add-ons
  sourceRepos: ["*"]
  destinations:
    - server: https://kubernetes.default.svc
      namespace: '*'
  clusterResourceWhitelist: [{group: '*', kind: '*'}]
EOF

# ARGO CD SELF-MANAGING — with the critical selfHeal: false / prune: false.
cat > "$REPO/addons/argo-cd/application.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-cd
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-100"
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-cd
    targetRevision: 7.6.12
    helm:
      values: |
        configs:
          params:
            server.insecure: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: false       # NEVER prune Argo CD itself
      selfHeal: false    # NEVER auto-heal Argo CD itself
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - RespectIgnoreDifferences=true
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers: [/spec/replicas]
EOF

cat > "$REPO/addons/metrics-server/application.yaml" <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: metrics-server
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://kubernetes-sigs.github.io/metrics-server/
    chart: metrics-server
    targetRevision: 3.12.2
    helm:
      values: |
        args: ["--kubelet-insecure-tls"]
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    automated: {prune: true, selfHeal: true}
EOF

cat > "$REPO/apps/guestbook/application.yaml" <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    path: guestbook
    targetRevision: HEAD
  destination:
    name: spoke
    namespace: guestbook
  syncPolicy:
    automated: {prune: true, selfHeal: true}
    syncOptions: ["CreateNamespace=true"]
EOF

# Make it a real git repo so Argo CD's git source works against file://
if [ ! -d "$REPO/.git" ]; then
  git -C "$REPO" init -q -b main
  git -C "$REPO" -c user.email=lab@local -c user.name=lab add -A
  git -C "$REPO" -c user.email=lab@local -c user.name=lab commit -q -m "initial bootstrap layout"
fi

echo "[1/5] bootstrap repo rendered at $REPO"
echo "       files:"
find "$REPO" -type f -not -path '*/.git/*' | sed "s|^|         |"

if [ "$LAYOUT_ONLY" = "1" ]; then
  echo "LAYOUT_ONLY requested — stopping before kind / kubectl steps."
  exit 0
fi

# ------------------------------------------------------------------------------
# 2) Create kind clusters
# ------------------------------------------------------------------------------
command -v kind >/dev/null || { echo "kind not installed"; exit 2; }
command -v kubectl >/dev/null || { echo "kubectl not installed"; exit 2; }

if ! kind get clusters | grep -qx "argo08-hub"; then
  kind create cluster --name argo08-hub
else
  echo "[kind] argo08-hub already exists"
fi

if [ "$SPOKE_ONLY" != "1" ]; then
  if ! kind get clusters | grep -qx "argo08-spoke"; then
    kind create cluster --name argo08-spoke
  else
    echo "[kind] argo08-spoke already exists"
  fi
fi

echo "[2/5] kind clusters ready"

# ------------------------------------------------------------------------------
# 3) Install Argo CD imperatively on the hub (first-time only)
# ------------------------------------------------------------------------------
kubectl --context "$HUB" get ns argocd >/dev/null 2>&1 \
  || kubectl --context "$HUB" create ns argocd
kubectl --context "$HUB" -n argocd apply \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_TAG}/manifests/install.yaml"
echo "[3/5] waiting for argocd-server..."
kubectl --context "$HUB" -n argocd rollout status deploy/argocd-server --timeout=240s

# ------------------------------------------------------------------------------
# 4) Register the spoke declaratively
# ------------------------------------------------------------------------------
if [ "$SPOKE_ONLY" != "1" ]; then
  NS=argocd-manager
  SA=argocd-manager
  kubectl --context "$SPOKE" get ns "$NS" >/dev/null 2>&1 || kubectl --context "$SPOKE" create ns "$NS"
  kubectl --context "$SPOKE" -n "$NS" get sa "$SA" >/dev/null 2>&1 || kubectl --context "$SPOKE" -n "$NS" create sa "$SA"
  kubectl --context "$SPOKE" get clusterrolebinding "$SA" >/dev/null 2>&1 \
    || kubectl --context "$SPOKE" create clusterrolebinding "$SA" \
         --clusterrole=cluster-admin --serviceaccount="$NS:$SA"
  TOKEN="$(kubectl --context "$SPOKE" -n "$NS" create token "$SA" --duration=24h)"
  CA_B64="$(kubectl --context "$SPOKE" config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"
  SPOKE_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' argo08-spoke-control-plane)"

  cat > "$REPO/clusters/spoke/cluster-secret.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cluster-spoke
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: spoke
  server: https://${SPOKE_IP}:6443
  config: |
    {"bearerToken":"${TOKEN}","tlsClientConfig":{"insecure":false,"caData":"${CA_B64}"}}
EOF
  kubectl --context "$HUB" apply -f "$REPO/clusters/spoke/cluster-secret.yaml"
  echo "[4/5] spoke registered as 'spoke'"
else
  # Point the guestbook Application at in-cluster instead of spoke
  sed -i.bak 's|name: spoke|server: https://kubernetes.default.svc|' "$REPO/apps/guestbook/application.yaml"
  rm -f "$REPO/apps/guestbook/application.yaml.bak"
  git -C "$REPO" -c user.email=lab@local -c user.name=lab commit -qam "spoke-only: target hub" || true
  echo "[4/5] spoke-only mode — guestbook targets in-cluster"
fi

# ------------------------------------------------------------------------------
# 5) Apply the root — the only hand-apply from here on
# ------------------------------------------------------------------------------
kubectl --context "$HUB" apply -f "$REPO/projects/platform.yaml"
kubectl --context "$HUB" apply -f "$REPO/bootstrap/root.yaml"
echo "[5/5] root applied. Waiting for Applications to appear (up to 90s)..."
for _ in $(seq 1 18); do
  n=$(kubectl --context "$HUB" -n argocd get applications --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [ "${n:-0}" -ge 3 ]; then break; fi
  sleep 5
done
kubectl --context "$HUB" -n argocd get applications

echo ""
echo "Done. Validate with: bash ../tests/validate.sh"
