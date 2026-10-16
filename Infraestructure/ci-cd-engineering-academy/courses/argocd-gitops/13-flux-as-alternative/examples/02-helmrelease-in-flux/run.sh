#!/usr/bin/env bash
# Example 02: deploy podinfo via HelmRelease and show Helm history.
# Note: no `set -o pipefail` — see example 01 for rationale.
set -eu

CLUSTER="flux-ex02"
NS="podinfo"

log()  { printf '\033[1;34m[ex02]\033[0m %s\n' "$*"; }
skip() { printf '\033[1;33m[ex02 SKIP]\033[0m %s\n' "$*"; exit 0; }
fail() { printf '\033[1;31m[ex02 FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

for bin in kind kubectl flux helm; do
  command -v "$bin" >/dev/null || skip "$bin not installed"
done

log "ensuring kind cluster '$CLUSTER'"
if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER" --wait 60s
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

log "flux install"
flux install --components=source-controller,kustomize-controller,helm-controller,notification-controller
kubectl -n flux-system wait --for=condition=Ready pod --all --timeout=180s || fail "flux-system not ready"

log "create target namespace"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

log "apply HelmRepository + HelmRelease"
cat <<EOF | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 10m
  url: https://stefanprodan.github.io/podinfo
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: podinfo
  namespace: ${NS}
spec:
  interval: 5m
  chart:
    spec:
      chart: podinfo
      version: ">=6.0.0"
      sourceRef:
        kind: HelmRepository
        name: podinfo
        namespace: flux-system
      interval: 10m
  install:
    remediation: { retries: 3 }
  upgrade:
    remediation: { retries: 3, remediateLastFailure: true }
  rollback:
    cleanupOnFail: true
  values:
    replicaCount: 2
    ingress: { enabled: false }
EOF

log "waiting for HelmRelease Ready=True (up to 3m)"
if ! kubectl -n "$NS" wait helmrelease/podinfo --for=condition=Ready --timeout=180s; then
  kubectl -n "$NS" describe helmrelease podinfo || true
  fail "HelmRelease did not become Ready"
fi

log "helm history (prueba de que fue 'helm install' real):"
helm -n "$NS" history podinfo || true

log "flux get helmreleases"
flux get helmreleases -A

cat <<'MSG'

== OBSERVACIÓN ==
  helm history muestra la revisión real. Con Argo CD + source.helm estaría vacío
  porque Argo CD hace 'helm template' y 'kubectl apply', no 'helm install'.

OK — ejemplo 02 completado. Limpia con: bash cleanup.sh
MSG
