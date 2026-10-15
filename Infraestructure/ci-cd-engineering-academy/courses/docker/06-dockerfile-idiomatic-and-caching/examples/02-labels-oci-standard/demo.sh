#!/usr/bin/env bash
# Build the image with OCI labels parametrized from "CI" and verify them.
# No `set -o pipefail` on purpose — we use `grep -q` and don't want SIGPIPE
# to turn a successful probe into a scripted failure.
set -eu

IMG="labels-demo:latest"
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

GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo abc1234)"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "== Building $IMG with GIT_SHA=$GIT_SHA BUILD_DATE=$BUILD_DATE =="
docker build \
  --build-arg GIT_SHA="$GIT_SHA" \
  --build-arg BUILD_DATE="$BUILD_DATE" \
  --build-arg APP_VERSION="1.0.0" \
  -t "$IMG" .

echo
echo "== Labels on the image =="
docker inspect --format '{{json .Config.Labels}}' "$IMG"

echo
echo "== Verifying the 10 recommended OCI annotations are present =="
LABELS_JSON="$(docker inspect --format '{{json .Config.Labels}}' "$IMG")"
expected=(
  "org.opencontainers.image.title"
  "org.opencontainers.image.description"
  "org.opencontainers.image.version"
  "org.opencontainers.image.authors"
  "org.opencontainers.image.source"
  "org.opencontainers.image.documentation"
  "org.opencontainers.image.licenses"
  "org.opencontainers.image.revision"
  "org.opencontainers.image.created"
  "org.opencontainers.image.vendor"
)
missing=0
for k in "${expected[@]}"; do
  if echo "$LABELS_JSON" | grep -q "\"$k\""; then
    echo "  OK  $k"
  else
    echo "  MISS $k"
    missing=$((missing+1))
  fi
done

if [ "$missing" -eq 0 ]; then
  echo
  echo "All 10 standard annotations present."
else
  echo
  echo "Missing $missing annotations." >&2
  exit 1
fi
