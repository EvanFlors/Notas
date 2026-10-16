#!/usr/bin/env bash
# Delete the two Applications and the two AppProjects. Also the test namespaces.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
NS=argocd

if ! command -v kubectl >/dev/null 2>&1 || ! kubectl config current-context >/dev/null 2>&1; then
  echo "SKIP: no kubectl / no current context."
  exit 0
fi

kubectl -n "$NS" delete -f "$HERE/app-payments-bad.yaml" --ignore-not-found
kubectl -n "$NS" delete -f "$HERE/app-payments-good.yaml" --ignore-not-found
kubectl -n "$NS" delete -f "$HERE/project-team-payments.yaml" --ignore-not-found
kubectl -n "$NS" delete -f "$HERE/project-team-checkout.yaml" --ignore-not-found
kubectl delete ns payments-dev --ignore-not-found
kubectl delete ns checkout-prod --ignore-not-found
echo "Clean."
