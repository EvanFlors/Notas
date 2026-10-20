#!/usr/bin/env bash
# Reference solution for helm-08-01 — MODE=local path.
# Produces the exact artifact layout that tests/validate.sh expects:
#   /tmp/helm-08-act01/mi-app-0.1.0.tgz
#   /tmp/helm-08-act01/keys/cosign.{key,pub}
#   oci://localhost:5000/charts/mi-app:0.1.0  (pushed + cosign-signed by digest)
#
# Note: NO `set -o pipefail` — some pipes to grep -q may yield SIGPIPE.
set -eu

BASE="${BASE:-/tmp/helm-08-act01}"
REG_CONTAINER="helm-08-act01-reg"
REG_HOST="localhost:5000"
CHART_NAME="mi-app"
CHART_VER="0.1.0"

if ! command -v helm >/dev/null 2>&1; then
  echo "SKIP: helm not installed."; exit 0
fi
if ! command -v cosign >/dev/null 2>&1; then
  echo "SKIP: cosign not installed."; exit 0
fi
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker not available."; exit 0
fi

echo "== helm-08-01 solution (MODE=local) at $BASE =="

rm -rf "$BASE"
mkdir -p "$BASE/keys"
cd "$BASE"

helm create "$CHART_NAME" >/dev/null
sed -i.bak -E "s/^version:.*/version: $CHART_VER/" "$CHART_NAME/Chart.yaml" && rm -f "$CHART_NAME/Chart.yaml.bak"
# Minimal personalization
sed -i.bak -E 's/^replicaCount: 1$/replicaCount: 2/' "$CHART_NAME/values.yaml" && rm -f "$CHART_NAME/values.yaml.bak"

helm package "$CHART_NAME" >/dev/null
TGZ="$BASE/${CHART_NAME}-${CHART_VER}.tgz"
echo "   packaged: $TGZ"

docker rm -f "$REG_CONTAINER" >/dev/null 2>&1 || true
docker run -d --rm --name "$REG_CONTAINER" -p 5000:5000 registry:2 >/dev/null
sleep 2

helm push "$TGZ" "oci://${REG_HOST}/charts" --plain-http >/dev/null
echo "   pushed to oci://${REG_HOST}/charts/${CHART_NAME}:${CHART_VER}"

export COSIGN_PASSWORD=''
(cd "$BASE/keys" && cosign generate-key-pair >/dev/null 2>&1)

DIGEST=$(curl -sfI -H "Accept: application/vnd.oci.image.manifest.v1+json" \
  "http://${REG_HOST}/v2/charts/${CHART_NAME}/manifests/${CHART_VER}" \
  | awk 'tolower($1)=="docker-content-digest:" {print $2}' | tr -d '\r')
IMG="${REG_HOST}/charts/${CHART_NAME}@${DIGEST}"
echo "   DIGEST: $DIGEST"

cosign sign --key "$BASE/keys/cosign.key" \
  --tlog-upload=false --allow-insecure-registry --yes "$IMG" >/dev/null 2>&1
echo "   signed."

cosign verify --key "$BASE/keys/cosign.pub" \
  --insecure-ignore-tlog --allow-insecure-registry "$IMG" >/dev/null 2>&1 \
  && echo "   verify OK" || { echo "   verify FAILED"; exit 1; }

echo
echo "DONE. Run tests/validate.sh to grade."
