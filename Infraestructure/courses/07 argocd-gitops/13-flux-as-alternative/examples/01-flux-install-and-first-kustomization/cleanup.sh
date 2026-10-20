#!/usr/bin/env bash
set -eu
CLUSTER="flux-ex01"
SCRATCH="/tmp/flux-ex01"
if command -v kind >/dev/null && kind get clusters | grep -qx "$CLUSTER"; then
  kind delete cluster --name "$CLUSTER"
fi
rm -rf "$SCRATCH"
echo "[ex01] cleaned up."
