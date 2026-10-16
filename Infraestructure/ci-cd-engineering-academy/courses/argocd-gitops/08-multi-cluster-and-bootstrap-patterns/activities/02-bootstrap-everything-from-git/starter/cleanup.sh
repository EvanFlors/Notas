#!/usr/bin/env bash
# Delete both kind clusters and the scratch dir.
set -eu

BASE="${BASE:-/tmp/argo08}"

for c in argo08-hub argo08-spoke; do
  if command -v kind >/dev/null && kind get clusters 2>/dev/null | grep -qx "$c"; then
    kind delete cluster --name "$c"
  else
    echo "kind cluster '$c' not present, skipping"
  fi
done

if [ -d "$BASE" ]; then
  rm -rf "$BASE"
  echo "removed $BASE"
fi

echo "cleanup done."
