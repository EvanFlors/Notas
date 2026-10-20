#!/usr/bin/env bash
# dkr-14 example 01 — generate SBOM in CycloneDX + SPDX from an OCI image.
# Degrades gracefully if docker/syft are missing.
#
# Note: no `set -o pipefail` on purpose — some pipes to grep -q may exit 141.
set -eu

BASE="${1:-/tmp/dkr-14-ex01}"
IMAGE_LOCAL="dkr-14-ex01-sbom-demo:v1"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== dkr-14 example 01 — syft SBOM =="
echo "   workdir: $BASE"

mkdir -p "$BASE"
cp "$HERE/Dockerfile.sample" "$BASE/Dockerfile"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed. Install from https://docs.docker.com/get-docker/"
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable."
  exit 0
fi

echo "-- Building image $IMAGE_LOCAL ..."
docker build -q -t "$IMAGE_LOCAL" "$BASE" >/dev/null

if ! command -v syft >/dev/null 2>&1; then
  echo "SKIP: syft not installed."
  echo "       Install: brew install syft"
  echo "            or: curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin"
  exit 0
fi

echo "-- Generating CycloneDX SBOM ..."
syft -q -o cyclonedx-json="$BASE/sbom.cdx.json" "$IMAGE_LOCAL"

echo "-- Generating SPDX SBOM ..."
syft -q -o spdx-json="$BASE/sbom.spdx.json" "$IMAGE_LOCAL"

if command -v jq >/dev/null 2>&1; then
  CDX_COUNT=$(jq '.components | length' "$BASE/sbom.cdx.json")
  SPDX_COUNT=$(jq '.packages | length' "$BASE/sbom.spdx.json")
  echo
  echo "SBOM CycloneDX: $BASE/sbom.cdx.json"
  echo "  Components: $CDX_COUNT"
  echo "SBOM SPDX:      $BASE/sbom.spdx.json"
  echo "  Packages:   $SPDX_COUNT"
else
  echo
  echo "SBOM CycloneDX: $BASE/sbom.cdx.json"
  echo "SBOM SPDX:      $BASE/sbom.spdx.json"
  echo "(install jq to see component count)"
fi

echo
echo "DONE. Inspect with:"
echo "  jq '.components[0]' $BASE/sbom.cdx.json"
