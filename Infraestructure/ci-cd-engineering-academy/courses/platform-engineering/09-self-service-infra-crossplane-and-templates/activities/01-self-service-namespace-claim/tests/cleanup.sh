#!/usr/bin/env bash
# Cleanup plat-09-01: delete cluster kind + scratch dir.
set -eu
CLUSTER="plat-09-01"
WORK="/tmp/plat-09-01"

if command -v kind >/dev/null 2>&1 && kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind delete cluster --name "$CLUSTER"
fi
rm -rf "$WORK"
echo "cleanup done."
