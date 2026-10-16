#!/usr/bin/env bash
# Clean up argo-04-01 cluster and scratch.
set -eu

CLUSTER=argo-04-01
if command -v kind >/dev/null 2>&1; then
  if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
    echo "Deleting kind cluster '$CLUSTER'..."
    kind delete cluster --name "$CLUSTER"
  else
    echo "Cluster '$CLUSTER' not present. Nothing to delete."
  fi
else
  echo "kind not installed — skipping cluster deletion."
fi

rm -rf /tmp/argo-04-01
echo "OK: cleanup done."
