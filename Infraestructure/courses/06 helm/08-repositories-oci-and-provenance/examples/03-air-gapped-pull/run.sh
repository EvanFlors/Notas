#!/usr/bin/env bash
# helm-08 example 03 — air-gapped consumption via helm pull.
# Dual-mode:
#   MODE=local (default) — producer uses registry:2 on localhost:5000;
#                          air-gap simulated by stopping the container.
#   MODE=live            — pulls from $REGISTRY/$CHART:$VERSION, then installs
#                          purely from the local .tgz.
#
# Note: no `set -o pipefail` — downstream pipes to grep -q may yield SIGPIPE.
set -eu

MODE="${MODE:-local}"
BASE="${1:-/tmp/helm-08-ex03}"

echo "== helm-08 example 03 — air-gapped pull (MODE=$MODE) =="
echo "   workdir: $BASE"

if ! command -v helm >/dev/null 2>&1; then
  echo "SKIP: helm not installed."
  exit 0
fi

rm -rf "$BASE"
mkdir -p "$BASE/transport"
cd "$BASE"

if [ "$MODE" = "local" ]; then
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "SKIP: docker not available for local registry."
    exit 0
  fi

  CHART_NAME="airgap-demo"
  CHART_VER="0.1.0"
  REG_CONTAINER="helm-08-ex03-reg"
  REG_PORT=5000
  REG_HOST="localhost:${REG_PORT}"

  # Phase 1: producer side
  echo "-- [producer] start registry ..."
  docker rm -f "$REG_CONTAINER" >/dev/null 2>&1 || true
  docker run -d --rm --name "$REG_CONTAINER" -p "${REG_PORT}:5000" registry:2 >/dev/null
  sleep 2

  echo "-- [producer] helm create + package ..."
  helm create "$CHART_NAME" >/dev/null
  sed -i.bak -E "s/^version:.*/version: $CHART_VER/" "$CHART_NAME/Chart.yaml" && rm -f "$CHART_NAME/Chart.yaml.bak"
  # Note: no subcharts for this smoke-test — keeps the example self-contained
  # and avoids pulling arbitrary deps from the internet. The §10 lesson still
  # applies: if the chart had deps, `helm dependency update` would have to run
  # here, before `helm package`, so the .tgz carries them.
  helm package "$CHART_NAME" >/dev/null
  TGZ_SRC="$BASE/${CHART_NAME}-${CHART_VER}.tgz"

  echo "-- [producer] helm push to local registry ..."
  helm push "$TGZ_SRC" "oci://${REG_HOST}/charts" --plain-http >/dev/null
  echo "   pushed."

  # Phase 2: transport
  echo "-- [transport] helm pull to transport/ ..."
  helm pull "oci://${REG_HOST}/charts/${CHART_NAME}" --version "$CHART_VER" \
    --plain-http --destination "$BASE/transport" >/dev/null
  TGZ_AIR="$BASE/transport/${CHART_NAME}-${CHART_VER}.tgz"
  if [ ! -f "$TGZ_AIR" ]; then
    echo "FAIL: did not pull $TGZ_AIR"
    exit 1
  fi
  echo "   transported: $TGZ_AIR"

  # Phase 3: cut the network (simulate air-gap)
  echo "-- [air-gap] stopping registry to prove no round-trip is needed ..."
  docker stop "$REG_CONTAINER" >/dev/null 2>&1 || true
  sleep 1

  echo "-- [air-gap] helm template from local .tgz (no registry) ..."
  if helm template my-release "$TGZ_AIR" >/dev/null; then
    echo "   OK — rendered without network."
  else
    echo "   FAIL — render from local .tgz failed."
    exit 1
  fi

  echo "-- [air-gap] helm install --dry-run from local .tgz (no cluster needed) ..."
  if helm install my-release "$TGZ_AIR" --dry-run --disable-openapi-validation >/dev/null 2>&1; then
    echo "   OK — dry-run install from local .tgz succeeded."
  else
    # Dry-run against no kubeconfig can emit non-fatal noise. Treat as acceptable
    # as long as template rendered above.
    echo "   NOTE — dry-run failed (likely no kubeconfig). Render still OK, which is the point."
  fi

  echo "-- [negative] confirm registry is really down ..."
  if helm pull "oci://${REG_HOST}/charts/${CHART_NAME}" --version "$CHART_VER" \
     --plain-http --destination "$BASE/should-fail" >/dev/null 2>&1; then
    echo "   UNEXPECTED PASS — registry should be down."
    exit 1
  else
    echo "   OK — pull failed as expected (registry stopped)."
  fi

  echo
  echo "DONE (MODE=local)."
  echo "  Local .tgz:    $TGZ_AIR"
  echo "  Cleanup:       rm -rf $BASE"

elif [ "$MODE" = "live" ]; then
  REGISTRY="${REGISTRY:-}"
  CHART="${CHART:-}"
  VERSION="${VERSION:-}"
  KUBE="${KUBE:-0}"
  if [ -z "$REGISTRY" ] || [ -z "$CHART" ] || [ -z "$VERSION" ]; then
    echo "FAIL: MODE=live requires REGISTRY, CHART, VERSION."
    echo "  Example: MODE=live REGISTRY=ghcr.io/yourorg CHART=charts/signed-demo VERSION=0.1.0 bash run.sh"
    exit 2
  fi

  echo "-- [transport] helm pull oci://${REGISTRY}/${CHART} v${VERSION} ..."
  helm pull "oci://${REGISTRY}/${CHART}" --version "$VERSION" \
    --destination "$BASE/transport"
  TGZ_AIR=$(ls "$BASE/transport"/*.tgz | head -1)
  echo "   got $TGZ_AIR"

  echo "-- [air-gap] helm template from local .tgz ..."
  helm template my-release "$TGZ_AIR" >/dev/null
  echo "   OK."

  if [ "$KUBE" = "1" ] && command -v kubectl >/dev/null 2>&1; then
    echo "-- [air-gap] helm install from local .tgz (real cluster) ..."
    helm install my-release "$TGZ_AIR" --wait --timeout 2m
    echo "   installed. (helm uninstall my-release to clean up)"
  else
    echo "-- Skipping real install (set KUBE=1 and have a cluster to attempt it)."
  fi

  echo
  echo "DONE (MODE=live)."
else
  echo "FAIL: unknown MODE='$MODE' (expected 'local' or 'live')."
  exit 2
fi
