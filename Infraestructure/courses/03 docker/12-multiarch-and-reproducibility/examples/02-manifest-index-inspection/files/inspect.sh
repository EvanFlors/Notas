#!/usr/bin/env bash
# Demo: inspect an OCI image index.
# Usage: ./inspect.sh [image-ref]   (default: alpine:3.20)
set -eu

REF="${1:-alpine:3.20}"

if ! docker buildx version >/dev/null 2>&1; then
  echo "SKIP: docker buildx not available."
  exit 0
fi

echo "== A) Human-readable inspect of $REF =="
docker buildx imagetools inspect "$REF"

echo
echo "== B) Raw index JSON =="
docker buildx imagetools inspect "$REF" --raw | sed -n '1,40p'

echo
echo "== C) Pick first linux/arm64 digest and inspect that manifest =="
# Grep (NO pipefail) the first arm64 digest from the human output.
digest="$(docker buildx imagetools inspect "$REF" \
  | awk '/^Name:/{n=$2} /^ *Platform:[[:space:]]*linux\/arm64/{print n; exit}' \
  | awk -F'@' '{print $2}')"

if [ -n "$digest" ]; then
  echo "  arm64 digest: $digest"
  docker buildx imagetools inspect "${REF%%:*}@${digest}" --raw | sed -n '1,40p'
else
  echo "  (no arm64 manifest found for $REF)"
fi
