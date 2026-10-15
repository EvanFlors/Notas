#!/usr/bin/env bash
# Demo: multi-arch build to a local registry:2.
# Idempotent: cleans previous registry/builder if present.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"

if ! docker buildx version >/dev/null 2>&1; then
  echo "SKIP: docker buildx not available."
  exit 0
fi

# 1) builder with network=host so BuildKit (in a container) can reach 127.0.0.1:5000
docker buildx rm multi >/dev/null 2>&1 || true
docker buildx create --name multi --driver docker-container \
  --driver-opt network=host --use >/dev/null
docker buildx inspect --bootstrap multi >/tmp/.ex01-inspect.log 2>&1 || {
  echo "FAIL: buildx bootstrap"; cat /tmp/.ex01-inspect.log; exit 1;
}

# 2) local registry
docker rm -f registry >/dev/null 2>&1 || true
docker run -d --rm --name registry -p 127.0.0.1:5000:5000 registry:2 >/dev/null

# Give the registry a moment to start.
for i in 1 2 3 4 5; do
  if curl -sf http://127.0.0.1:5000/v2/ >/dev/null 2>&1; then break; fi
  sleep 1
done

# 3) build + push multi-arch
docker buildx build \
  --builder multi \
  --platform linux/amd64,linux/arm64 \
  --provenance=false \
  -t 127.0.0.1:5000/hello:v1 \
  --push \
  "$HERE"

# 4) inspect
docker buildx imagetools inspect 127.0.0.1:5000/hello:v1

echo "== DONE =="
echo "Cleanup: docker rm -f registry && docker buildx rm multi"
