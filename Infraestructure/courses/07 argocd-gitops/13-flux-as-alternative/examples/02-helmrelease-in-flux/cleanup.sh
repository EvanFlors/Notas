#!/usr/bin/env bash
set -eu
CLUSTER="flux-ex02"
if command -v kind >/dev/null && kind get clusters | grep -qx "$CLUSTER"; then
  kind delete cluster --name "$CLUSTER"
fi
echo "[ex02] cleaned up."
