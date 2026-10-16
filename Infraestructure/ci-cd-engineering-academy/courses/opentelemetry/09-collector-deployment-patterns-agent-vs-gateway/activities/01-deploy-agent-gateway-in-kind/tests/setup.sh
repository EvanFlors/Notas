#!/usr/bin/env bash
# Setup cluster kind y aplica los manifiestos del alumno.
# Si quedan REPLACE_ME, falla con mensaje.
# No pipefail (grep -q + pipes).
set -eu

CLUSTER="otel-09-01"
NS="observability"
HERE="$(cd "$(dirname "$0")" && pwd)"
ACT="$(cd "$HERE/.." && pwd)"
WORK="/tmp/otel-09-01"
mkdir -p "$WORK"

MANIFESTS_DIR="${MANIFESTS_DIR:-$ACT/starter}"
echo "Usando manifiestos de: $MANIFESTS_DIR"

skip() { echo "SKIP: $1"; exit 0; }
command -v docker  >/dev/null 2>&1 || skip "docker no instalado"
command -v kind    >/dev/null 2>&1 || skip "kind no instalado"
command -v kubectl >/dev/null 2>&1 || skip "kubectl no instalado"
docker info >/dev/null 2>&1          || skip "docker daemon no responde"

if grep -l 'REPLACE_ME' "$MANIFESTS_DIR"/*.yaml >/dev/null 2>&1; then
  echo "ERROR: hay 'REPLACE_ME' pendientes en $MANIFESTS_DIR:"
  grep -l 'REPLACE_ME' "$MANIFESTS_DIR"/*.yaml
  echo "Completa los TODO antes de ejecutar setup."
  exit 1
fi

echo "== kind create cluster (si no existe) =="
if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --config "$ACT/starter/kind-config.yaml" --name "$CLUSTER"
fi
kubectl config use-context "kind-$CLUSTER"

echo "== namespace $NS =="
kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -

echo "== apply gateway =="
kubectl apply -f "$MANIFESTS_DIR/gateway.yaml"
kubectl -n "$NS" rollout status deploy/otel-gateway --timeout=120s

echo "== apply agent =="
kubectl apply -f "$MANIFESTS_DIR/agent.yaml"
kubectl -n "$NS" rollout status ds/otel-agent --timeout=120s

echo "setup OK."
