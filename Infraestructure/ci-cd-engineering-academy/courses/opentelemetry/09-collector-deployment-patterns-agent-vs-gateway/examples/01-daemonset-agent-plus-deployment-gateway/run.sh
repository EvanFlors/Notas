#!/usr/bin/env bash
# Example 01 — DaemonSet agent + Deployment gateway (kind).
# Idempotent. Skips gracefully if kind/kubectl/docker missing.
#
# Note: deliberately NO `set -o pipefail` because some checks use
# `kubectl ... | grep -q ...` which produces SIGPIPE spurious failures.
set -eu

CLUSTER="otel-09-ex01"
NS="observability"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="/tmp/otel-09-ex01"
mkdir -p "$WORK"

skip() { echo "SKIP: $1"; exit 0; }

command -v docker  >/dev/null 2>&1 || skip "docker no instalado"
command -v kind    >/dev/null 2>&1 || skip "kind no instalado"
command -v kubectl >/dev/null 2>&1 || skip "kubectl no instalado"
docker info >/dev/null 2>&1          || skip "docker daemon no responde"

echo "== 1. kind create cluster (si no existe) =="
if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --config "$HERE/kind-config.yaml" --name "$CLUSTER"
else
  echo "  cluster $CLUSTER ya existe"
fi
kubectl config use-context "kind-$CLUSTER"

echo "== 2. namespace $NS =="
kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -

echo "== 3. aplica gateway (primero, para que el agent lo resuelva) =="
kubectl apply -f "$HERE/gateway-deployment.yaml"
kubectl -n "$NS" rollout status deploy/otel-gateway --timeout=120s

echo "== 4. aplica agent (DaemonSet) =="
kubectl apply -f "$HERE/agent-daemonset.yaml"
kubectl -n "$NS" rollout status ds/otel-agent --timeout=120s

echo "== 5. generar 100 spans con telemetrygen =="
kubectl -n "$NS" delete job telemetrygen --ignore-not-found
kubectl apply -f "$HERE/generate-traces.yaml"
kubectl -n "$NS" wait --for=condition=complete job/telemetrygen --timeout=90s || true

echo "== 6. buscar ResourceSpans en los logs del gateway =="
sleep 5
count="$(kubectl -n "$NS" logs deploy/otel-gateway --tail=500 | grep -c 'ResourceSpans' || true)"
echo "  spans batches observados: $count"

if [ "$count" -gt 0 ]; then
  echo "OK: gateway recibió telemetría del pipeline."
else
  echo "WARN: no se vieron ResourceSpans; revisa logs manualmente:"
  echo "      kubectl -n $NS logs deploy/otel-gateway"
fi

echo
echo "Para explorar:"
echo "  kubectl -n $NS get all"
echo "  kubectl -n $NS logs deploy/otel-gateway | tail -40"
echo
echo "Para limpiar:  bash $HERE/cleanup.sh"
