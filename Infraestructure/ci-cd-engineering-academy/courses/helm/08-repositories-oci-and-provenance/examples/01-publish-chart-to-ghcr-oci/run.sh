#!/usr/bin/env bash
# helm-08 example 01 — publish a chart to an OCI registry.
# Dual-mode:
#   MODE=local (default) — registry:2 on localhost:5000, --plain-http.
#   MODE=live            — pushes to $REGISTRY (e.g. ghcr.io/yourorg).
#
# Note: no `set -o pipefail` — downstream pipes to grep -q may yield SIGPIPE.
set -eu

MODE="${MODE:-local}"
BASE="${1:-/tmp/helm-08-ex01}"

echo "== helm-08 example 01 — publish chart to OCI (MODE=$MODE) =="
echo "   workdir: $BASE"

if ! command -v helm >/dev/null 2>&1; then
  echo "SKIP: helm not installed. Install: brew install helm"
  exit 0
fi

CHART_NAME="oci-demo"
CHART_VER="0.1.0"

rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

echo "-- helm create $CHART_NAME ..."
helm create "$CHART_NAME" >/dev/null
# Lock the version to be deterministic
sed -i.bak -E "s/^version:.*/version: $CHART_VER/" "$CHART_NAME/Chart.yaml" && rm -f "$CHART_NAME/Chart.yaml.bak"

echo "-- helm package ..."
helm package "$CHART_NAME" >/dev/null
TGZ="$BASE/${CHART_NAME}-${CHART_VER}.tgz"
if [ ! -f "$TGZ" ]; then
  echo "FAIL: package not produced at $TGZ"
  exit 1
fi
echo "   produced: $TGZ"

if [ "$MODE" = "local" ]; then
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "SKIP: docker not available for local registry."
    exit 0
  fi

  REG_CONTAINER="helm-08-ex01-reg"
  REG_PORT=5000
  REG_HOST="localhost:${REG_PORT}"

  if ! docker ps --format '{{.Names}}' | grep -q "^${REG_CONTAINER}$"; then
    # Clean any stopped container with same name
    docker rm -f "$REG_CONTAINER" >/dev/null 2>&1 || true
    echo "-- starting local registry ($REG_CONTAINER) on :$REG_PORT ..."
    docker run -d --rm --name "$REG_CONTAINER" -p "${REG_PORT}:5000" registry:2 >/dev/null
    sleep 2
  else
    echo "-- registry $REG_CONTAINER already running."
  fi

  echo "-- helm push oci://${REG_HOST}/charts (--plain-http) ..."
  helm push "$TGZ" "oci://${REG_HOST}/charts" --plain-http >/dev/null
  echo "   pushed."

  echo "-- list tags via registry API ..."
  TAGS=$(curl -sf "http://${REG_HOST}/v2/charts/${CHART_NAME}/tags/list" || echo '{}')
  echo "   $TAGS"
  if ! echo "$TAGS" | grep -q "\"$CHART_VER\""; then
    echo "FAIL: tag $CHART_VER not present in registry listing."
    exit 1
  fi

  echo "-- helm pull round-trip ..."
  mkdir -p "$BASE/pulled"
  helm pull "oci://${REG_HOST}/charts/${CHART_NAME}" --version "$CHART_VER" \
    --plain-http --destination "$BASE/pulled" >/dev/null
  if [ ! -f "$BASE/pulled/${CHART_NAME}-${CHART_VER}.tgz" ]; then
    echo "FAIL: pulled .tgz not present."
    exit 1
  fi
  echo "   pulled: $BASE/pulled/${CHART_NAME}-${CHART_VER}.tgz"

  echo "-- helm show chart ..."
  helm show chart "oci://${REG_HOST}/charts/${CHART_NAME}" --version "$CHART_VER" \
    --plain-http | head -10

  echo
  echo "DONE (MODE=local)."
  echo "  Chart:   oci://${REG_HOST}/charts/${CHART_NAME}:${CHART_VER}"
  echo "  Cleanup: docker stop ${REG_CONTAINER} ; rm -rf ${BASE}"

elif [ "$MODE" = "live" ]; then
  REGISTRY="${REGISTRY:-}"
  if [ -z "$REGISTRY" ]; then
    echo "FAIL: MODE=live requires REGISTRY (e.g. REGISTRY=ghcr.io/yourorg)."
    exit 2
  fi

  echo "-- helm push oci://${REGISTRY}/charts ..."
  echo "   (requires prior: echo \$GHCR_TOKEN | helm registry login ghcr.io -u \$GHCR_USER --password-stdin)"
  helm push "$TGZ" "oci://${REGISTRY}/charts"

  echo "-- helm show chart ..."
  helm show chart "oci://${REGISTRY}/charts/${CHART_NAME}" --version "$CHART_VER" | head -10

  echo
  echo "DONE (MODE=live)."
  echo "  Chart: oci://${REGISTRY}/charts/${CHART_NAME}:${CHART_VER}"
  echo "  Check visibility of the new package in the registry UI."
else
  echo "FAIL: unknown MODE='$MODE' (expected 'local' or 'live')."
  exit 2
fi
