#!/usr/bin/env bash
# dkr-04-02 — set up a deliberately broken bind mount scenario.
# Reproducible on both native Linux and Docker Desktop (macOS/Windows).
# Idempotent.
set -eu

IMAGE="dkr04-02-writer:latest"
HOST_DIR="/tmp/dkr04-02-output"
WRONG_UID=2000   # not 1000, not the host user — guaranteed to fail

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker CLI not found."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: Docker daemon not reachable."
  exit 0
fi

HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== Building image $IMAGE (writes as UID 1000, checks /output owner strictly) =="
docker build -t "$IMAGE" "$HERE" >/dev/null
echo "Image built."

echo "== Preparing host output directory with MISMATCHED ownership =="
# We use docker-side chown so this works consistently on both native Linux
# (where chown is a real syscall against the host FS) and Docker Desktop
# (where the Linux VM owns a virtual view of the bind). The important fact:
# from any container's point of view, /tmp/dkr04-02-output will NOT be owned
# by UID 1000.
rm -rf "$HOST_DIR"
mkdir -p "$HOST_DIR"
docker run --rm \
  --mount type=bind,source="$HOST_DIR",target=/x \
  alpine:3.20 chown "$WRONG_UID":"$WRONG_UID" /x

echo "Container-view ownership of $HOST_DIR:"
docker run --rm \
  --mount type=bind,source="$HOST_DIR",target=/x \
  alpine:3.20 stat -c '  uid=%u gid=%g perms=%a path=%n' /x

echo
echo "Setup complete. Now try: bash starter/run-broken.sh (it must fail)."
echo "Then apply a fix and re-run until the writer succeeds."
