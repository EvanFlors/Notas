#!/usr/bin/env bash
# dkr-14 example 03 — cosign sign + verify (local key pair OR keyless OIDC).
# Dual-mode:
#   MODE=local (default) — registry:2 on localhost:5000, cosign with local key pair.
#   MODE=live            — pushes to $REGISTRY, uses keyless OIDC.
#
# Note: no `set -o pipefail` — downstream pipes to grep -q may yield SIGPIPE.
set -eu

MODE="${MODE:-local}"
BASE="${1:-/tmp/dkr-14-ex03}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== dkr-14 example 03 — cosign sign + verify (MODE=$MODE) =="
echo "   workdir: $BASE"

mkdir -p "$BASE" "$BASE/keys"
cp "$HERE/Dockerfile.sample" "$BASE/Dockerfile"

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker not available."
  exit 0
fi
if ! command -v cosign >/dev/null 2>&1; then
  echo "SKIP: cosign not installed. Install: brew install cosign"
  exit 0
fi

if [ "$MODE" = "local" ]; then
  REG_CONTAINER="dkr-14-ex03-reg"
  REG_PORT=5000
  IMAGE_TAG="localhost:${REG_PORT}/cosign-demo:v1"

  # Registry
  if ! docker ps --format '{{.Names}}' | grep -q "^${REG_CONTAINER}$"; then
    echo "-- Starting local registry ($REG_CONTAINER) on :$REG_PORT ..."
    docker run -d --rm --name "$REG_CONTAINER" -p "${REG_PORT}:5000" registry:2 >/dev/null
    sleep 2
  fi

  echo "-- Build + push $IMAGE_TAG ..."
  docker build -q -t "$IMAGE_TAG" "$BASE" >/dev/null
  docker push -q "$IMAGE_TAG" >/dev/null

  DIGEST=$(docker inspect "$IMAGE_TAG" --format='{{index .RepoDigests 0}}' | awk -F@ '{print $2}')
  IMG="localhost:${REG_PORT}/cosign-demo@${DIGEST}"
  echo "   digest: $DIGEST"
  echo "   IMG:    $IMG"

  echo "-- Generate key pair ..."
  export COSIGN_PASSWORD=''
  if [ ! -f "$BASE/keys/cosign.key" ]; then
    (cd "$BASE/keys" && cosign generate-key-pair >/dev/null 2>&1)
  fi

  echo "-- Sign (local key, no Rekor) ..."
  cosign sign --key "$BASE/keys/cosign.key" --tlog-upload=false --yes "$IMG" >/dev/null 2>&1
  echo "   signed."

  echo "-- Verify with CORRECT key (expect OK) ..."
  if cosign verify --key "$BASE/keys/cosign.pub" --insecure-ignore-tlog "$IMG" >/dev/null 2>&1; then
    echo "   OK — signature verified."
  else
    echo "   FAIL — verification should have succeeded."
    exit 1
  fi

  echo "-- Negative test: verify with WRONG key (expect FAIL) ..."
  mkdir -p "$BASE/other-keys"
  (cd "$BASE/other-keys" && cosign generate-key-pair >/dev/null 2>&1)
  if cosign verify --key "$BASE/other-keys/cosign.pub" --insecure-ignore-tlog "$IMG" >/dev/null 2>&1; then
    echo "   UNEXPECTED PASS — wrong key verified. Something is wrong."
    exit 1
  else
    echo "   OK — wrong key correctly rejected."
  fi

  echo
  echo "DONE (MODE=local)."
  echo "  Image:  $IMG"
  echo "  Keys:   $BASE/keys/"
  echo "  Cleanup: docker stop $REG_CONTAINER ; rm -rf $BASE"

elif [ "$MODE" = "live" ]; then
  REGISTRY="${REGISTRY:-}"
  if [ -z "$REGISTRY" ]; then
    echo "FAIL: MODE=live requires REGISTRY (e.g. REGISTRY=ghcr.io/youruser)."
    exit 2
  fi
  IMAGE_TAG="${REGISTRY}/cosign-demo:v1"

  echo "-- Build + push $IMAGE_TAG (requires prior docker login) ..."
  docker build -q -t "$IMAGE_TAG" "$BASE" >/dev/null
  docker push -q "$IMAGE_TAG" >/dev/null

  DIGEST=$(docker inspect "$IMAGE_TAG" --format='{{index .RepoDigests 0}}' | awk -F@ '{print $2}')
  IMG="${REGISTRY}/cosign-demo@${DIGEST}"
  echo "   IMG: $IMG"

  echo "-- Sign keyless (opens browser if local; uses OIDC token in GHA) ..."
  cosign sign --yes "$IMG"

  echo "-- Verify (requires knowing the identity regex and issuer) ..."
  echo "   Example:"
  echo "     cosign verify $IMG \\"
  echo "       --certificate-identity-regexp 'https://github\\.com/YOUR_ORG/.*' \\"
  echo "       --certificate-oidc-issuer     'https://token.actions.githubusercontent.com'"
else
  echo "FAIL: unknown MODE='$MODE' (expected 'local' or 'live')."
  exit 2
fi
