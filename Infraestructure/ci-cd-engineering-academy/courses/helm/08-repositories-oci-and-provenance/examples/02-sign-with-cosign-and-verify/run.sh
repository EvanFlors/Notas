#!/usr/bin/env bash
# helm-08 example 02 — cosign sign a Helm OCI chart + verify + negative test.
# Dual-mode:
#   MODE=local (default) — registry:2, cosign local keypair, --tlog-upload=false.
#   MODE=live            — ghcr.io/$REGISTRY, cosign keyless (OIDC).
#
# Note: no `set -o pipefail` — downstream pipes to grep -q may yield SIGPIPE.
set -eu

MODE="${MODE:-local}"
BASE="${1:-/tmp/helm-08-ex02}"

echo "== helm-08 example 02 — cosign sign + verify (MODE=$MODE) =="
echo "   workdir: $BASE"

if ! command -v helm >/dev/null 2>&1; then
  echo "SKIP: helm not installed."
  exit 0
fi
if ! command -v cosign >/dev/null 2>&1; then
  echo "SKIP: cosign not installed. Install: brew install cosign"
  exit 0
fi

CHART_NAME="signed-demo"
CHART_VER="0.1.0"

rm -rf "$BASE"
mkdir -p "$BASE" "$BASE/keys"
cd "$BASE"

echo "-- helm create + package $CHART_NAME ..."
helm create "$CHART_NAME" >/dev/null
sed -i.bak -E "s/^version:.*/version: $CHART_VER/" "$CHART_NAME/Chart.yaml" && rm -f "$CHART_NAME/Chart.yaml.bak"
helm package "$CHART_NAME" >/dev/null
TGZ="$BASE/${CHART_NAME}-${CHART_VER}.tgz"

if [ "$MODE" = "local" ]; then
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "SKIP: docker not available for local registry."
    exit 0
  fi

  REG_CONTAINER="helm-08-ex02-reg"
  REG_PORT=5000
  REG_HOST="localhost:${REG_PORT}"

  if ! docker ps --format '{{.Names}}' | grep -q "^${REG_CONTAINER}$"; then
    docker rm -f "$REG_CONTAINER" >/dev/null 2>&1 || true
    echo "-- starting local registry ($REG_CONTAINER) on :$REG_PORT ..."
    docker run -d --rm --name "$REG_CONTAINER" -p "${REG_PORT}:5000" registry:2 >/dev/null
    sleep 2
  fi

  echo "-- helm push oci://${REG_HOST}/charts --plain-http ..."
  PUSH_OUT=$(helm push "$TGZ" "oci://${REG_HOST}/charts" --plain-http 2>&1)
  echo "$PUSH_OUT"
  # Extract Digest from helm push output
  DIGEST=$(echo "$PUSH_OUT" | awk '/Digest:/ {print $2}')
  if [ -z "$DIGEST" ]; then
    # Fallback: query the registry manifest
    DIGEST=$(curl -sfI -H "Accept: application/vnd.oci.image.manifest.v1+json" \
      "http://${REG_HOST}/v2/charts/${CHART_NAME}/manifests/${CHART_VER}" \
      | awk 'tolower($1)=="docker-content-digest:" {print $2}' | tr -d '\r')
  fi
  if [ -z "$DIGEST" ]; then
    echo "FAIL: could not resolve chart digest."
    exit 1
  fi
  IMG="${REG_HOST}/charts/${CHART_NAME}@${DIGEST}"
  echo "   digest: $DIGEST"
  echo "   IMG:    $IMG"

  echo "-- generate cosign keypair (empty password) ..."
  export COSIGN_PASSWORD=''
  if [ ! -f "$BASE/keys/cosign.key" ]; then
    (cd "$BASE/keys" && cosign generate-key-pair >/dev/null 2>&1)
  fi

  echo "-- cosign sign (local key, no Rekor, --allow-insecure-registry) ..."
  cosign sign --key "$BASE/keys/cosign.key" \
    --tlog-upload=false --allow-insecure-registry --yes "$IMG" >/dev/null 2>&1
  echo "   signed."

  echo "-- cosign verify with CORRECT key (expect OK) ..."
  if cosign verify --key "$BASE/keys/cosign.pub" \
      --insecure-ignore-tlog --allow-insecure-registry "$IMG" >/dev/null 2>&1; then
    echo "   OK — signature verified."
  else
    echo "   FAIL — verification should have succeeded."
    exit 1
  fi

  echo "-- negative test: verify with WRONG key (expect FAIL) ..."
  mkdir -p "$BASE/other-keys"
  (cd "$BASE/other-keys" && cosign generate-key-pair >/dev/null 2>&1)
  if cosign verify --key "$BASE/other-keys/cosign.pub" \
      --insecure-ignore-tlog --allow-insecure-registry "$IMG" >/dev/null 2>&1; then
    echo "   UNEXPECTED PASS — wrong key verified. Aborting."
    exit 1
  else
    echo "   OK — wrong key correctly rejected."
  fi

  echo
  echo "DONE (MODE=local)."
  echo "  Chart:   oci://${REG_HOST}/charts/${CHART_NAME}:${CHART_VER}"
  echo "  Digest:  ${DIGEST}"
  echo "  Keys:    ${BASE}/keys/"
  echo "  Cleanup: docker stop ${REG_CONTAINER} ; rm -rf ${BASE}"

elif [ "$MODE" = "live" ]; then
  REGISTRY="${REGISTRY:-}"
  if [ -z "$REGISTRY" ]; then
    echo "FAIL: MODE=live requires REGISTRY (e.g. REGISTRY=ghcr.io/yourorg)."
    exit 2
  fi

  echo "-- helm push oci://${REGISTRY}/charts ..."
  PUSH_OUT=$(helm push "$TGZ" "oci://${REGISTRY}/charts" 2>&1)
  echo "$PUSH_OUT"
  DIGEST=$(echo "$PUSH_OUT" | awk '/Digest:/ {print $2}')
  if [ -z "$DIGEST" ]; then
    echo "FAIL: could not resolve digest from helm push output."
    exit 1
  fi
  IMG="${REGISTRY}/charts/${CHART_NAME}@${DIGEST}"
  echo "   IMG: $IMG"

  echo "-- cosign sign KEYLESS (opens browser locally; uses OIDC token in GHA) ..."
  cosign sign --yes "$IMG"

  echo "-- verify requires knowing the identity OIDC used to sign."
  echo "   Example (from GHA workflow signer):"
  echo "     cosign verify $IMG \\"
  echo "       --certificate-identity-regexp 'https://github\\.com/yourorg/.*' \\"
  echo "       --certificate-oidc-issuer     'https://token.actions.githubusercontent.com'"

  echo
  echo "DONE (MODE=live)."
else
  echo "FAIL: unknown MODE='$MODE' (expected 'local' or 'live')."
  exit 2
fi
