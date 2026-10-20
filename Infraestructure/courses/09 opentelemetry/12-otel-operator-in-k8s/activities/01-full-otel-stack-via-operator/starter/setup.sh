#!/usr/bin/env bash
# Setup for otel-12-01: creates kind cluster, installs cert-manager + OTel Operator,
# namespaces, and stages the manifests under /tmp/otel-12-lab/.
#
# Idempotent: re-running from scratch is safe.
#
# NOTE: no `set -o pipefail` on purpose (grep -q on kind get clusters).

set -eu

CLUSTER="otel-12-lab"
HERE="$(cd "$(dirname "$0")" && pwd)"
STAGE="/tmp/otel-12-lab"
CM_VERSION="v1.15.0"
OTEL_OP_URL="https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "SKIP: '$1' not installed; this lab requires kind + kubectl."
    exit 0
  fi
}

need kind
need kubectl

mkdir -p "$STAGE"
cp -f "$HERE/manifests/"*.yaml "$STAGE/"

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "== creating kind cluster '$CLUSTER' =="
  kind create cluster --name "$CLUSTER" --wait 90s >/dev/null
else
  echo "== kind cluster '$CLUSTER' already exists =="
fi

echo "== installing cert-manager $CM_VERSION =="
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CM_VERSION}/cert-manager.yaml" >/dev/null
kubectl -n cert-manager wait --for=condition=Available --timeout=180s deploy --all >/dev/null

echo "== installing OTel Operator =="
kubectl apply -f "$OTEL_OP_URL" >/dev/null
kubectl -n opentelemetry-operator-system wait --for=condition=Available --timeout=180s deploy --all >/dev/null

echo "== creating namespaces =="
kubectl create ns observability --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create ns demo --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo
echo "Setup OK."
echo "Manifests staged at: $STAGE"
echo "Next: apply them in order 01 -> 02 -> 03 -> 04 (see README.md)."
