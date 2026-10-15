#!/usr/bin/env bash
# Build a deliberately bloated image, then run dive on it (or textual fallback).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable."
  exit 0
fi

echo "building app:bloated ..."
docker build -q -t app:bloated . >/dev/null
echo "built."

if command -v dive >/dev/null 2>&1; then
  echo "launching dive (press Ctrl+C or Q to exit) ..."
  dive app:bloated || true
else
  echo "SKIP: dive not installed. Falling back to 'docker history'."
  echo
  docker history --no-trunc --format "table {{.Size}}\t{{.CreatedBy}}" app:bloated
  echo
  echo "Look for the 'rm -rf /root/.cache/pip' layer — it adds 0 bytes but"
  echo "the preceding 'pip install' layer still ships the cache. That is the"
  echo "whiteout anti-pattern dive would highlight visually."
fi

echo
echo "cleanup: docker rmi app:bloated"
docker rmi app:bloated >/dev/null 2>&1 || true
echo "done."
