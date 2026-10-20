#!/usr/bin/env bash
# Reference solution MODE=local for gha-14-01.
# Reproduce: build + push al registry local + SBOM + sign + verify.
# Gracefully skips cosign/syft si no están instalados.
set -euo pipefail

BASE="${1:-/tmp/gha-14-01}"
REG_CONTAINER="gha-14-01-registry"
REG_PORT=5050
IMAGE_TAG="localhost:${REG_PORT}/app:v0.1.0"

if [ ! -f "$BASE/Dockerfile" ]; then
  echo "FAIL: $BASE/Dockerfile missing. Corre starter/bootstrap.sh primero."
  exit 1
fi
cd "$BASE"

if ! command -v docker >/dev/null 2>&1; then
  echo "FAIL: docker no instalado."
  exit 2
fi

# 1) Registry local
if ! docker ps --format '{{.Names}}' | grep -q "^${REG_CONTAINER}$"; then
  docker run -d --rm --name "$REG_CONTAINER" -p "${REG_PORT}:5000" registry:2 >/dev/null
  sleep 2
fi

# 2) Build + push
docker build -t "$IMAGE_TAG" .
docker push "$IMAGE_TAG"

# 3) Digest
DIGEST="$(docker inspect "$IMAGE_TAG" --format='{{index .RepoDigests 0}}' | awk -F@ '{print $2}')"
IMG="localhost:${REG_PORT}/app@${DIGEST}"
echo "Digest: $DIGEST"

# 4) SBOM (si syft disponible)
if command -v syft >/dev/null 2>&1; then
  syft -o cyclonedx-json="sbom/sbom.cdx.json" "$IMG"
  echo "SBOM: $(jq '.components | length' sbom/sbom.cdx.json) components"
else
  echo "SKIP: syft no instalado. SBOM no generado."
fi

# 5) Firma (si cosign disponible)
if command -v cosign >/dev/null 2>&1; then
  export COSIGN_PASSWORD=''
  if [ ! -f keys/cosign.key ]; then
    (cd keys && cosign generate-key-pair)
  fi
  cosign sign --key keys/cosign.key --tlog-upload=false --yes "$IMG"
  cosign verify --key keys/cosign.pub --insecure-ignore-tlog "$IMG" \
    --output=json | jq -r '.[0].critical.image.docker_manifest_digest'
else
  echo "SKIP: cosign no instalado. Firma/verify no ejecutados."
fi

# 6) Workflow para MODE=live
cp "$(dirname "$0")/release.yml" .github/workflows/release.yml

echo
echo "DONE."
echo "  Imagen firmada: $IMG"
echo "  Workflow:       .github/workflows/release.yml"
