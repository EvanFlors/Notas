#!/usr/bin/env bash
# Setup for otel-12-02: reuses cluster 'otel-12-lab' if present; otherwise creates
# a minimal cluster and installs cert-manager + OTel Operator. Applies a baseline
# OpenTelemetryCollector/upgradable with image=0.110.0 so the student can upgrade.
#
# NOTE: no `set -o pipefail` on purpose.

set -eu

CLUSTER="otel-12-lab"
HERE="$(cd "$(dirname "$0")" && pwd)"
CM_VERSION="v1.15.0"
OTEL_OP_URL="https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml"
SCRATCH="/tmp/otel-12-02"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "SKIP: '$1' not installed; Mode B (documentation-only) is available."
    exit 0
  fi
}

need kind
need kubectl
mkdir -p "$SCRATCH"
cp -f "$HERE/manifests/"*.yaml "$SCRATCH/"

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "== creating kind cluster '$CLUSTER' =="
  kind create cluster --name "$CLUSTER" --wait 90s >/dev/null
else
  echo "== reusing existing kind cluster '$CLUSTER' =="
fi

# Install cert-manager + Operator only if not present.
if ! kubectl -n cert-manager get deploy cert-manager-webhook >/dev/null 2>&1; then
  echo "== installing cert-manager =="
  kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CM_VERSION}/cert-manager.yaml" >/dev/null
  kubectl -n cert-manager wait --for=condition=Available --timeout=180s deploy --all >/dev/null
fi
if ! kubectl -n opentelemetry-operator-system get deploy >/dev/null 2>&1; then
  echo "== installing OTel Operator =="
  kubectl apply -f "$OTEL_OP_URL" >/dev/null
  kubectl -n opentelemetry-operator-system wait --for=condition=Available --timeout=180s deploy --all >/dev/null
fi

kubectl create ns observability --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "== applying baseline Collector (image 0.110.0) =="
kubectl apply -f "$SCRATCH/upgradable-v0.yaml"
for _ in $(seq 1 30); do
  kubectl -n observability get deploy upgradable-collector >/dev/null 2>&1 && break
  sleep 2
done
kubectl -n observability rollout status deploy/upgradable-collector --timeout=120s || true

echo
echo "Setup OK."
echo "Baseline CR applied (image 0.110.0). Scratch dir: $SCRATCH"
echo "Next: edit the CR to upgrade image and add a processor."
