#!/usr/bin/env bash
# Demonstrate that --mount=type=cache reuses pip downloads across builds.
#
# Strategy:
#   1. Clean docker build cache + pip cache mount.
#   2. First build: pip downloads wheels from PyPI (slow).
#   3. Invalidate the layer cache for RUN pip install by touching requirements.txt
#      with an identical content hash... actually we invalidate it by changing
#      the file timestamp AND adding a harmless comment, then reverting. For
#      simplicity we instead force a rebuild with --no-cache but KEEP the
#      BuildKit cache mount via --cache-from (not needed, mount survives).
#      In practice: --no-cache invalidates layer cache; the mount persists.
#   4. Second build with --no-cache: layer cache is cold BUT the pip cache
#      mount still has the wheels — install is noticeably faster.
#
# Note: no `set -o pipefail` on purpose — see pipefail comment in
# courses/git-and-github/02-recording-changes/activities/02-recover-from-mistakes/tests/validate.sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
IMG="cache-mount-demo:latest"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable."
  exit 0
fi

echo "== Pruning build cache AND the pip cache mount =="
docker builder prune -af >/dev/null 2>&1 || true
# Specifically prune cache mounts (type=exec.cachemount in BuildKit).
docker builder prune -af --filter type=exec.cachemount >/dev/null 2>&1 || true

echo
echo "== First build (cold: pip must download from PyPI) =="
time docker build --no-cache -t "$IMG" .

echo
echo "== Second build (--no-cache: layer cache cold, but pip cache mount is warm) =="
time docker build --no-cache -t "$IMG" .

echo
echo "== Inspecting the mount is NOT in the image =="
if docker run --rm "$IMG" ls /root/.cache/pip 2>/dev/null; then
  echo "WARN: /root/.cache/pip exists in the image. Should be empty/absent."
else
  echo "OK: /root/.cache/pip is NOT baked into the image."
fi
