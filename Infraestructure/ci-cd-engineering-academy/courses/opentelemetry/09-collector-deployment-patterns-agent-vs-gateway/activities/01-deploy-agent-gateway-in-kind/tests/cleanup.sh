#!/usr/bin/env bash
set -eu
CLUSTER="otel-09-01"
WORK="/tmp/otel-09-01"
if command -v kind >/dev/null 2>&1 && kind get clusters | grep -qx "$CLUSTER"; then
  kind delete cluster --name "$CLUSTER"
fi
rm -rf "$WORK"
echo "cleanup done."
