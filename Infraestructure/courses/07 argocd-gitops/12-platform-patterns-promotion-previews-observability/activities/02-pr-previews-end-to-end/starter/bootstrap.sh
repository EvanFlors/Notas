#!/usr/bin/env bash
# Bootstrap kind + Argo CD + ApplicationSet (previews) for the lab.
# Idempotent: safe to re-run. `--clean` tears down the cluster.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks use
# `kubectl ... | grep -q ...` which closes the upstream early; pipefail would
# mark those as failed.
set -eu

CLUSTER="${CLUSTER:-argo-12-ex}"
SCRATCH="/tmp/argo-12-prprev"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ "${1:-}" = "--clean" ]; then
  echo "[clean] deleting kind cluster $CLUSTER and scratch $SCRATCH"
  kind delete cluster --name "$CLUSTER" 2>/dev/null || true
  rm -rf "$SCRATCH"
  exit 0
fi

for bin in kind kubectl yq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: $bin not found in PATH" >&2
    exit 2
  fi
done

mkdir -p "$SCRATCH"

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "[kind] creating cluster $CLUSTER"
  kind create cluster --name "$CLUSTER" --wait 90s
else
  echo "[kind] cluster $CLUSTER already exists"
fi

kubectl config use-context "kind-$CLUSTER" >/dev/null

if ! kubectl get ns argocd >/dev/null 2>&1; then
  echo "[argocd] installing"
  kubectl create namespace argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
else
  echo "[argocd] namespace exists, ensuring manifests"
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
fi

echo "[argocd] waiting for deployments to roll out"
for d in argocd-server argocd-repo-server argocd-applicationset-controller; do
  kubectl -n argocd rollout status deploy/"$d" --timeout=240s
done
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=240s

echo "[appset] applying AppProject and ApplicationSet"
kubectl apply -f "$HERE/project.yaml"
kubectl apply -f "$HERE/appset.yaml"

# Initialize the list to empty so no previews exist at boot.
yq -i '.spec.generators[0].list.elements = []' "$HERE/appset.yaml"
kubectl apply -f "$HERE/appset.yaml"

echo
echo "[done] cluster ready. Try:  ./pr-open.sh 123"
