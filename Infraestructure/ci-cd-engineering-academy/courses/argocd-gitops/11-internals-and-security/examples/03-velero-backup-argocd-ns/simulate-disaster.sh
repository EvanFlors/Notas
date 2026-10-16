#!/usr/bin/env bash
# Delete one Application and corrupt argocd-cm.
# The restore.sh script should bring both back.
set -eu

APP="${APP:-}"
if [ -z "$APP" ]; then
  APP="$(kubectl -n argocd get applications -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo '')"
fi
if [ -z "$APP" ]; then
  echo "WARN: no Applications found to delete — simulating only CM damage."
else
  echo "== Deleting Application argocd/$APP =="
  kubectl -n argocd delete application "$APP" --wait=true
fi

echo "== Patching argocd-cm with wrong URL =="
kubectl -n argocd patch cm argocd-cm --type merge \
  -p '{"data":{"url":"https://DAMAGED.example.invalid"}}'

echo
echo "State after disaster:"
kubectl -n argocd get applications 2>/dev/null || true
kubectl -n argocd get cm argocd-cm -o jsonpath='{.data.url}'; echo
