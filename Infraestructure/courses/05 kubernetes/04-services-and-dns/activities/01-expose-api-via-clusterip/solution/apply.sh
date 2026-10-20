#!/usr/bin/env bash
# Reference solution for k8s-04-01: apply the manifest and verify from a client Pod.
# Assumes a kind (or any) cluster is reachable via the current kubectl context.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

kubectl apply -f "$HERE/manifest.yaml"
kubectl rollout status deploy/webapi --timeout=90s

echo "== svc =="
kubectl get svc webapi
echo "== endpoints =="
kubectl get endpoints webapi

kubectl run tmp --image=curlimages/curl:8.9.1 --rm -i --restart=Never --quiet -- \
  curl -sS -o /dev/null -w "short: HTTP %{http_code}\n" http://webapi

kubectl run tmp --image=curlimages/curl:8.9.1 --rm -i --restart=Never --quiet -- \
  curl -sS -o /dev/null -w "fqdn:  HTTP %{http_code}\n" http://webapi.default.svc.cluster.local
