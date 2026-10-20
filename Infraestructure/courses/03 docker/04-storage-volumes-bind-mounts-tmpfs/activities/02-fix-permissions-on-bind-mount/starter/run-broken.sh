#!/usr/bin/env bash
# dkr-04-02 — runs the writer container exactly as "shipped from vendor".
# DO NOT MODIFY THIS FILE as part of your fix. The fix must come from
# the environment (ownership of the host dir, user namespace, etc.), not here.
set -eu

IMAGE="dkr04-02-writer:latest"
HOST_DIR="/tmp/dkr04-02-output"
CONTAINER="dkr04-02-writer"

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: Docker not available."
  exit 0
fi

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

echo "Running $IMAGE with bind mount $HOST_DIR -> /output ..."
docker run --name "$CONTAINER" \
  --mount type=bind,source="$HOST_DIR",target=/output \
  "$IMAGE"
rc=$?
echo "Exit code: $rc"
exit $rc
