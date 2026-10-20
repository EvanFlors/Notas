#!/usr/bin/env bash
# Cleanup example 02 — delete claim, composition, xrd, team-foo namespace.
set -eu
WORK="/tmp/plat-09-ex02"

if command -v kubectl >/dev/null 2>&1 && kubectl version --request-timeout=5s >/dev/null 2>&1; then
  kubectl -n team-foo delete namespaceproductclaim demo --ignore-not-found --wait=false
  # delete XR by name if still around
  kubectl delete xnamespaceproduct --all --ignore-not-found --wait=false || true
  kubectl delete composition xnamespaceproducts.k8s-native --ignore-not-found || true
  kubectl delete xrd xnamespaceproducts.platform.io --ignore-not-found || true
  kubectl delete ns demo-ns --ignore-not-found --wait=false || true
  kubectl delete ns team-foo --ignore-not-found --wait=false || true
fi
rm -rf "$WORK"
echo "cleanup done."
