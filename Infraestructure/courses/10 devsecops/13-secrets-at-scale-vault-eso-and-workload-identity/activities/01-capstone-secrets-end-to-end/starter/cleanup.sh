#!/usr/bin/env bash
# Elimina cluster kind + contenedor Vault + scratch dir.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early.
set -eu

CLUSTER=sec-13-capstone

if command -v kind >/dev/null 2>&1 && kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind delete cluster --name "$CLUSTER"
fi

if command -v docker >/dev/null 2>&1; then
  docker rm -f sec-13-vault >/dev/null 2>&1 || true
fi

rm -rf /tmp/sec-13-capstone
echo "Cleanup done."
