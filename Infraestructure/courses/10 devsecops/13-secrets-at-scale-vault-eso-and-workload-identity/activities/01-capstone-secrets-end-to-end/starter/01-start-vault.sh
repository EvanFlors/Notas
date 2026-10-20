#!/usr/bin/env bash
# Arranca Vault en modo dev (in-memory, token=root). DEV ONLY.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
set -eu

WORK=/tmp/sec-13-capstone
mkdir -p "$WORK"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed."
  exit 0
fi

echo "== Starting Vault 1.15 dev (DEV MODE — token=root, in-memory) =="
docker rm -f sec-13-vault >/dev/null 2>&1 || true
docker run -d --name sec-13-vault \
  --cap-add=IPC_LOCK \
  -p 8200:8200 \
  -e VAULT_DEV_ROOT_TOKEN_ID=root \
  -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
  hashicorp/vault:1.15 >/dev/null

sleep 3

if command -v vault >/dev/null 2>&1; then
  export VAULT_ADDR=http://127.0.0.1:8200
  export VAULT_TOKEN=root
  vault status >/dev/null && echo "Vault OK on $VAULT_ADDR (token=root — DEV ONLY)."
else
  echo "WARN: 'vault' CLI not installed on host; container is up, but you won't be able to configure it. Install from https://developer.hashicorp.com/vault/install"
fi
