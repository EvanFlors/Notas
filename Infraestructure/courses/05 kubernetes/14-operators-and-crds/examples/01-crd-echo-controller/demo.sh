#!/usr/bin/env bash
# Demo: create a kind cluster, install the Echo CRD, create a sample CR,
# and show that the apiserver accepts it even without a controller.
# Idempotent. Cleans up at the end unless KEEP=1 is set.
#
# Usage:
#   bash demo.sh          # run and clean up
#   KEEP=1 bash demo.sh   # run and leave the cluster

set -eu

CLUSTER="k8s-14-echo-demo"
HERE="$(cd "$(dirname "$0")" && pwd)"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "SKIP: '$1' not installed; this demo requires kind + kubectl."
    exit 0
  fi
}

cleanup() {
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

echo "== creating kind cluster '$CLUSTER' =="
kind create cluster --name "$CLUSTER" --wait 60s >/dev/null

echo "== applying CRD =="
kubectl apply -f "$HERE/crd-echo.yaml"
kubectl wait --for condition=Established --timeout=30s crd/echoes.demo.academy.io

echo "== creating sample Echo CR =="
kubectl apply -f "$HERE/echo-sample.yaml"

echo "== listing echoes (no controller, status will be empty) =="
kubectl get echoes
kubectl get echo hello -o yaml | sed -n '1,40p'

echo
echo "Lesson: the apiserver stored the CR, validated the schema, and listed it"
echo "with the printer columns. But .status is empty because nobody runs a Reconcile."
