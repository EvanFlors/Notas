#!/usr/bin/env bash
# Reference solution for k8s-03-01-deploy-fastapi.
# Idempotent: safe to re-run.
set -eu

NS="k8s-03-01"
HERE="$(cd "$(dirname "$0")" && pwd)"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl no está instalado."
  exit 0
fi
if ! kubectl config current-context >/dev/null 2>&1 \
   || ! kubectl get --raw=/readyz --request-timeout=10s >/dev/null 2>&1; then
  echo "SKIP: no hay cluster accesible."
  exit 0
fi

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$HERE/deployment.yaml"
kubectl rollout status "deployment/fastapi-stub" -n "$NS" --timeout=300s

# Trigger a rollout so history has 2+ revisions.
kubectl set image "deployment/fastapi-stub" web=nginx:1.27-alpine -n "$NS"
kubectl annotate "deployment/fastapi-stub" -n "$NS" \
  kubernetes.io/change-cause="bump to nginx 1.27-alpine" --overwrite
kubectl rollout status "deployment/fastapi-stub" -n "$NS" --timeout=300s

# Back to the tag the validator expects.
kubectl set image "deployment/fastapi-stub" web=nginxdemos/hello:plain-text -n "$NS"
kubectl rollout status "deployment/fastapi-stub" -n "$NS" --timeout=300s

echo "OK — Deployment fastapi-stub listo en namespace $NS."
