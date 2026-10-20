#!/usr/bin/env bash
# Demo: install cert-manager + OTel Operator in a kind cluster, apply an
# OpenTelemetryCollector CR, show the generated objects, then clean up.
#
# Idempotent. Set KEEP=1 to leave the cluster alive.
#
# NOTE: we do NOT enable `set -o pipefail` because some checks pipe into
# `grep -q`, which closes the pipe early and can SIGPIPE the upstream — pipefail
# would spuriously fail those steps.

set -eu

CLUSTER="otel-12-ex01"
HERE="$(cd "$(dirname "$0")" && pwd)"
CM_VERSION="v1.15.0"
OTEL_OP_URL="https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml"
SCRATCH="/tmp/otel-12-ex01"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "SKIP: '$1' not installed; this demo requires kind + kubectl."
    exit 0
  fi
}

cleanup() {
  rm -rf "$SCRATCH"
  if [ "${KEEP:-0}" != "1" ]; then
    echo "== cleanup: deleting kind cluster '$CLUSTER' =="
    kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
  else
    echo "== KEEP=1: leaving cluster '$CLUSTER' running =="
  fi
}
trap cleanup EXIT

need kind
need kubectl

mkdir -p "$SCRATCH"

echo "== creating kind cluster '$CLUSTER' =="
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER" --wait 90s >/dev/null
fi

echo "== installing cert-manager $CM_VERSION =="
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CM_VERSION}/cert-manager.yaml" >/dev/null
echo "   waiting for cert-manager deployments..."
kubectl -n cert-manager wait --for=condition=Available --timeout=180s deploy --all >/dev/null

echo "== installing OpenTelemetry Operator =="
kubectl apply -f "$OTEL_OP_URL" >/dev/null
echo "   waiting for operator deployment..."
kubectl -n opentelemetry-operator-system wait --for=condition=Available --timeout=180s deploy --all >/dev/null

echo "== CRDs installed =="
kubectl get crds | awk '/opentelemetry.io/ {print "  - "$1}'

echo "== creating namespace observability =="
kubectl create ns observability --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "== applying OpenTelemetryCollector/gateway =="
kubectl apply -f "$HERE/collector-deployment.yaml"

echo "   waiting for the generated deployment to roll out..."
# The Operator names the deployment "<cr-name>-collector".
for _ in $(seq 1 30); do
  if kubectl -n observability get deploy gateway-collector >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
kubectl -n observability rollout status deploy/gateway-collector --timeout=120s

echo "== objects reconciled by the CR =="
kubectl -n observability get otelcol,configmap,deploy,svc,sa -l app.kubernetes.io/managed-by=opentelemetry-operator

echo "== rendered ConfigMap (first 30 lines) =="
cm_name="$(kubectl -n observability get cm -l app.kubernetes.io/managed-by=opentelemetry-operator -o jsonpath='{.items[0].metadata.name}')"
kubectl -n observability get cm "$cm_name" -o yaml | sed -n '1,30p'

echo
echo "Lesson: the CR 'gateway' became a ConfigMap + Deployment + Service + SA."
echo "        If you 'kubectl delete deploy/gateway-collector', the Operator recreates it."
