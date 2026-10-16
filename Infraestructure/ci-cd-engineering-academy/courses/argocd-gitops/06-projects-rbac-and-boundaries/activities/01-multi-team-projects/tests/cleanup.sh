#!/usr/bin/env bash
# Remove everything created by this activity.
set -eu
NS=argocd

if ! command -v kubectl >/dev/null 2>&1 || ! kubectl config current-context >/dev/null 2>&1; then
  echo "SKIP: no kubectl / no current context."
  exit 0
fi

kubectl -n "$NS" delete application payments-good --ignore-not-found
kubectl -n "$NS" delete application checkout-crossing --ignore-not-found
kubectl -n "$NS" delete appproject team-payments --ignore-not-found
kubectl -n "$NS" delete appproject team-checkout --ignore-not-found
kubectl delete ns payments-dev --ignore-not-found
kubectl delete ns payments-prod --ignore-not-found
kubectl delete ns checkout-prod --ignore-not-found
echo "Clean."
