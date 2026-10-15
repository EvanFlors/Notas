#!/usr/bin/env bash
set -eu
IMAGE="dkr04-02-writer:latest"
HOST_DIR="/tmp/dkr04-02-output"
CONTAINER="dkr04-02-writer"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker rmi -f "$IMAGE" >/dev/null 2>&1 || true
fi
# chmod first in case dir ended up unwritable to current user
chmod -R u+rwx "$HOST_DIR" 2>/dev/null || true
rm -rf "$HOST_DIR"
echo "Cleaned."
