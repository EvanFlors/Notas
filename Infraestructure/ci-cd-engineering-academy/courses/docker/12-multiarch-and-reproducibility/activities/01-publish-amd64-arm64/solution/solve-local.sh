#!/usr/bin/env bash
# Reference solution for dkr-12-01-publish-amd64-arm64 (MODE=local).
# Bootstraps, creates a docker-container builder, and does the multi-arch push.
set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${1:-/tmp/dkr-12-publish}"
BUILDER="dkr12"
REF="127.0.0.1:5050/dkr-12-app:v1"

bash "$HERE/starter/bootstrap.sh" "$BASE" >/dev/null

# Create builder (idempotente). network=host permite que BuildKit (que corre
# en un contenedor) alcance el registry local en 127.0.0.1:5050.
if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
  docker buildx create --name "$BUILDER" --driver docker-container \
    --driver-opt network=host >/dev/null
fi
docker buildx inspect --bootstrap "$BUILDER" >/dev/null
docker buildx use "$BUILDER"

docker buildx build \
  --builder "$BUILDER" \
  --platform linux/amd64,linux/arm64 \
  --provenance=false \
  -t "$REF" \
  --push \
  "$BASE/app"

echo
echo "== Solution built. Verify: =="
docker buildx imagetools inspect "$REF"
