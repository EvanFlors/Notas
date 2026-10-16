#!/usr/bin/env bash
# Demo: show that the OTel Operator's mutating webhook auto-injects the Python
# SDK into any Pod carrying the annotation `instrumentation.opentelemetry.io/
# inject-python=true`.
#
# NOTE: no `set -o pipefail` on purpose — `grep -q` on piped `kubectl get`
# output can SIGPIPE the upstream and spuriously fail with pipefail.

set -eu

CLUSTER="otel-12-ex02"
HERE="$(cd "$(dirname "$0")" && pwd)"
EX01="$(cd "$HERE/../01-operator-install-and-collector-cr" && pwd)"
CM_VERSION="v1.15.0"
OTEL_OP_URL="https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml"
SCRATCH="/tmp/otel-12-ex02"

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

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "== creating kind cluster '$CLUSTER' =="
  kind create cluster --name "$CLUSTER" --wait 90s >/dev/null
fi

echo "== installing cert-manager + OTel Operator =="
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CM_VERSION}/cert-manager.yaml" >/dev/null
kubectl -n cert-manager wait --for=condition=Available --timeout=180s deploy --all >/dev/null
kubectl apply -f "$OTEL_OP_URL" >/dev/null
kubectl -n opentelemetry-operator-system wait --for=condition=Available --timeout=180s deploy --all >/dev/null

echo "== applying gateway Collector =="
kubectl create ns observability --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -f "$EX01/collector-deployment.yaml"
# Wait briefly for the Operator to create the deployment.
for _ in $(seq 1 30); do
  kubectl -n observability get deploy gateway-collector >/dev/null 2>&1 && break
  sleep 2
done
kubectl -n observability rollout status deploy/gateway-collector --timeout=120s

echo "== applying Instrumentation CR and Python Pod =="
kubectl create ns demo --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -f "$HERE/instrumentation.yaml"
kubectl apply -f "$HERE/python-app.yaml"
kubectl -n demo rollout status deploy/pyapp --timeout=120s

echo "== Pod after mutation (initContainers + env) =="
pod="$(kubectl -n demo get pod -l app=pyapp -o jsonpath='{.items[0].metadata.name}')"
echo "   pod: $pod"
echo
echo "-- initContainers --"
kubectl -n demo get pod "$pod" -o jsonpath='{range .spec.initContainers[*]}{.name}{"\n"}{end}'
echo
echo "-- app container env (OTEL_* only) --"
kubectl -n demo get pod "$pod" -o jsonpath='{range .spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' | grep '^OTEL_\|^PYTHONPATH' || true

echo
echo "== generating traffic (10 requests) =="
kubectl -n demo port-forward svc/pyapp 18080:8080 >/dev/null 2>&1 &
pf=$!
sleep 2
for i in $(seq 1 10); do curl -s -o /dev/null "http://127.0.0.1:18080/" || true; done
kill "$pf" >/dev/null 2>&1 || true

echo "== gateway Collector logs (last lines; should show spans) =="
kubectl -n observability logs deploy/gateway-collector --tail=40 || true

echo
echo "Lesson: the app image was never rebuilt. The webhook mutated the Pod spec"
echo "        at admission time, adding an initContainer that supplies the SDK."
