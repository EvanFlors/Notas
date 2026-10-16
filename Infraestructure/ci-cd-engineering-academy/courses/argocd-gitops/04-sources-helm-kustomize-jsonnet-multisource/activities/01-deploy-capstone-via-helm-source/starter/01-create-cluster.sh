#!/usr/bin/env bash
# Create a local kind cluster for argo-04-01.
# Scratch dir: /tmp/argo-04-01/. Idempotent.
set -eu

CLUSTER=argo-04-01
SCRATCH=/tmp/argo-04-01
mkdir -p "$SCRATCH"

if ! command -v kind >/dev/null 2>&1; then
  echo "SKIP: kind not installed. See https://kind.sigs.k8s.io/."
  exit 0
fi
if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed."
  exit 0
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed/running."
  exit 0
fi

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "Cluster '$CLUSTER' already exists. Reusing."
else
  echo "Creating kind cluster '$CLUSTER'..."
  kind create cluster --name "$CLUSTER" --wait 120s
fi

kubectl cluster-info --context "kind-$CLUSTER" >/dev/null
echo "OK: kind cluster '$CLUSTER' ready."
