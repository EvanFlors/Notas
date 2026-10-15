#!/usr/bin/env bash
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

echo "building app:scratch ..."
docker build -q -t app:scratch . >/dev/null
echo "built."
echo
echo "TAG                  SIZE"
docker images --format "{{.Repository}}:{{.Tag}}  {{.Size}}" | grep '^app:scratch '
echo
echo "runtime check:"
docker run --rm app:scratch
echo
echo "cleanup: docker rmi app:scratch"
docker rmi app:scratch >/dev/null 2>&1 || true
echo "done."
