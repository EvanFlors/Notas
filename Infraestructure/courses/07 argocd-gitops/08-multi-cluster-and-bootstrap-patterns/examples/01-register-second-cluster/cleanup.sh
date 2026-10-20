#!/usr/bin/env bash
# Delete both kind clusters created by this example.
set -eu

for c in argo-hub argo-spoke; do
  if kind get clusters 2>/dev/null | grep -qx "$c"; then
    kind delete cluster --name "$c"
  else
    echo "kind cluster '$c' not present, skipping"
  fi
done
