#!/usr/bin/env bash
# Crea el cluster kind 'sec-13-capstone' y conecta Vault a la red kind.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
set -eu

CLUSTER=sec-13-capstone

for tool in kind kubectl docker; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP: $tool not installed."
    exit 0
  fi
done

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "Cluster '$CLUSTER' already exists; reusing."
else
  echo "== Creating kind cluster '$CLUSTER' =="
  kind create cluster --name "$CLUSTER"
fi

# Conecta Vault a la red kind para que el API server y Vault se vean.
if docker ps --format '{{.Names}}' | grep -qx 'sec-13-vault'; then
  docker network connect kind sec-13-vault 2>/dev/null || true
  echo "Vault joined 'kind' docker network."
else
  echo "WARN: sec-13-vault container not running. Run ./01-start-vault.sh first."
fi

kubectl --context "kind-$CLUSTER" get nodes
