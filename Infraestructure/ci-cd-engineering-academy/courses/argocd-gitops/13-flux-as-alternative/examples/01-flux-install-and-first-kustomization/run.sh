#!/usr/bin/env bash
# Example 01: install Flux in a kind cluster and reconcile a first Kustomization.
# Idempotent. SKIPs cleanly when flux/kind missing.
#
# Note: we intentionally do NOT enable `set -o pipefail`. Several checks use
# `cmd | grep -q ...`; grep closes early on match and the upstream command may
# receive SIGPIPE (exit 141). pipefail would mark those as failure spuriously.
set -eu

CLUSTER="flux-ex01"
SCRATCH="/tmp/flux-ex01"
NS="podinfo"

log()  { printf '\033[1;34m[ex01]\033[0m %s\n' "$*"; }
skip() { printf '\033[1;33m[ex01 SKIP]\033[0m %s\n' "$*"; exit 0; }
fail() { printf '\033[1;31m[ex01 FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

command -v kind    >/dev/null || skip "kind not installed"
command -v kubectl >/dev/null || skip "kubectl not installed"
command -v flux    >/dev/null || skip "flux CLI not installed (brew install fluxcd/tap/flux)"

mkdir -p "$SCRATCH"

log "ensuring kind cluster '$CLUSTER'"
if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER" --wait 60s
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

log "flux check --pre"
flux check --pre || fail "flux pre-check failed"

log "flux install (idempotent)"
flux install --components=source-controller,kustomize-controller,helm-controller,notification-controller

log "waiting for flux-system pods"
kubectl -n flux-system wait --for=condition=Ready pod --all --timeout=180s || fail "flux-system pods not ready"

log "creating GitRepository 'podinfo' (public repo)"
cat <<'EOF' | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/stefanprodan/podinfo
  ref:
    branch: master
EOF

log "creating target namespace '$NS'"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

log "creating Kustomization 'podinfo'"
cat <<EOF | kubectl apply -f -
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 5m
  path: "./kustomize"
  prune: true
  sourceRef:
    kind: GitRepository
    name: podinfo
  targetNamespace: ${NS}
  wait: true
  timeout: 3m
EOF

log "waiting for Kustomization Ready=True (up to 3m)"
if ! kubectl -n flux-system wait kustomization/podinfo --for=condition=Ready --timeout=180s; then
  kubectl -n flux-system describe kustomization podinfo || true
  fail "Kustomization did not become Ready"
fi

log "resources in namespace '$NS':"
kubectl -n "$NS" get all

log "flux get kustomizations"
flux get kustomizations -A

cat <<'MSG'

== EQUIVALENCIAS ARGO CD → FLUX ==
  argocd app create         ≈  GitRepository + Kustomization
  argocd app sync           ≈  flux reconcile kustomization <name>
  argocd app get            ≈  flux get kustomization <name>
  argocd app history        ≈  (git log del repo + flux stats)
  UI resource tree          ≈  flux tree kustomization <name>

OK — ejemplo 01 completado. Limpia con: bash cleanup.sh
MSG
