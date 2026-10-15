#!/usr/bin/env bash
# cert-manager.sh — install cert-manager (dependency of the OTel Operator webhook).
#
# Note: deliberately no 'set -o pipefail' because we use 'grep -q' further below and
# pipefail would surface SIGPIPE as a spurious failure.
set -u

echo "== Installing cert-manager =="

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed."
  exit 0
fi

VERSION="v1.15.3"
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${VERSION}/cert-manager.yaml"

echo "Waiting for cert-manager to be Ready..."
kubectl -n cert-manager wait --for=condition=Available --timeout=180s \
  deploy/cert-manager deploy/cert-manager-webhook deploy/cert-manager-cainjector

echo "OK: cert-manager installed."
