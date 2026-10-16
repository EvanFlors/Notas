#!/usr/bin/env bash
# Reference solution: install Flux + apply manifests.yaml.
# Idempotent. Use 'cleanup' subcommand to tear everything down.
# Note: no `set -o pipefail` — grep -q with piped producers can trigger SIGPIPE.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
CLUSTER="argo-13-01"

log()  { printf '\033[1;34m[argo-13-01]\033[0m %s\n' "$*"; }
skip() { printf '\033[1;33m[argo-13-01 SKIP]\033[0m %s\n' "$*"; exit 0; }
fail() { printf '\033[1;31m[argo-13-01 FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

cmd="${1:-apply}"

if [ "$cmd" = "cleanup" ]; then
  if command -v kind >/dev/null && kind get clusters | grep -qx "$CLUSTER"; then
    kind delete cluster --name "$CLUSTER"
  fi
  echo "[argo-13-01] cleaned up."
  exit 0
fi

for bin in kind kubectl flux; do
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

log "applying manifests.yaml"
kubectl apply -f "$HERE/manifests.yaml"

log "waiting for HelmRelease capstone/capstone Ready=True (up to 3m)"
if ! kubectl -n capstone wait helmrelease/capstone --for=condition=Ready --timeout=180s; then
  kubectl -n capstone describe helmrelease capstone || true
  fail "HelmRelease did not become Ready"
fi

log "resources in namespace 'capstone':"
kubectl -n capstone get all

cat <<'MSG'

OK — portado. Ejecuta 'bash ../tests/validate.sh' para validar.
Limpia con: bash run.sh cleanup
MSG
