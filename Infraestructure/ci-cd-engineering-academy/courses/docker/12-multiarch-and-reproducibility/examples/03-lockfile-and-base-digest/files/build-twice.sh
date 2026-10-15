#!/usr/bin/env bash
# Build the Dockerfile twice with reproducibility flags; compare sha256sum.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1700000000}"
OUT_A="/tmp/dkr-12-ex03-a.tar"
OUT_B="/tmp/dkr-12-ex03-b.tar"
BUILDER="dkr12-ex03"

if ! docker buildx version >/dev/null 2>&1; then
  echo "SKIP: docker buildx not available."
  exit 0
fi

# Use a container-driver builder so we have the OCI exporter + rewrite-timestamp.
if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
  docker buildx create --name "$BUILDER" --driver docker-container >/dev/null
fi
docker buildx inspect --bootstrap "$BUILDER" >/dev/null

rm -f "$OUT_A" "$OUT_B"

for OUT in "$OUT_A" "$OUT_B"; do
  docker buildx build \
    --builder "$BUILDER" \
    --provenance=false --sbom=false \
    --build-arg SOURCE_DATE_EPOCH \
    --output "type=oci,dest=$OUT,rewrite-timestamp=true" \
    "$HERE"
done

SUM_A="$(sha256sum "$OUT_A" | awk '{print $1}')"
SUM_B="$(sha256sum "$OUT_B" | awk '{print $1}')"

echo
echo "SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH"
echo "A: $SUM_A  $OUT_A"
echo "B: $SUM_B  $OUT_B"
if [ "$SUM_A" = "$SUM_B" ]; then
  echo "REPRODUCIBLE: sha256sum coincide."
  exit 0
else
  echo "NOT REPRODUCIBLE: los sha256 difieren."
  exit 1
fi
