#!/usr/bin/env bash
# Solution de referencia para helm-02-01-install-cert-manager.
# Deliberadamente SIN `set -o pipefail`: algunos checks usan `cmd | grep -q`
# y pipefail promovería un SIGPIPE del upstream a fallo del pipeline.
set -eu

WORK="/tmp/helm-02-01"
RELEASE="cert-manager"
NS="cert-manager"
VERSION="v1.16.2"

mkdir -p "$WORK"

# 0. Preflight.
for bin in helm kubectl; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Falta '$bin' en el PATH." >&2
    exit 1
  fi
done

# 1. Repo (idempotente).
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update jetstack >/dev/null

# 2. Install idempotente (idiom de CI/CD).
helm upgrade --install "$RELEASE" jetstack/cert-manager \
  --namespace "$NS" --create-namespace \
  --version "$VERSION" \
  --set crds.enabled=true \
  --wait --timeout 5m

# 3. Snapshot.
{
  echo "# snapshot helm-02-01"
  echo
  echo "## release"
  helm list -n "$NS"
  echo
  echo "## status"
  helm status "$RELEASE" -n "$NS"
  echo
  echo "## release-secret"
  kubectl get secret -n "$NS" -l owner=helm
  echo
  echo "## crds"
  kubectl get crd | grep cert-manager.io
} > "$WORK/snapshot.md"

echo
echo "Solution aplicada. Correr validator:"
echo "  bash courses/helm/02-consume-charts-install-upgrade-rollback/activities/01-install-cert-manager/tests/validate.sh"
