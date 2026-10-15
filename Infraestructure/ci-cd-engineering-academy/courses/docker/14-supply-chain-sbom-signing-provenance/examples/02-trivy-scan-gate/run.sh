#!/usr/bin/env bash
# dkr-14 example 02 — trivy scan as CI gate.
# Builds a deliberately old alpine image and shows the difference between
# an informational scan and a gated scan (--exit-code 1).
#
# Note: no `set -o pipefail` — downstream pipes to grep -q may yield SIGPIPE.
set -eu

BASE="${1:-/tmp/dkr-14-ex02}"
IMAGE="dkr-14-ex02-demo:v1"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== dkr-14 example 02 — trivy as gate =="
echo "   workdir: $BASE"

mkdir -p "$BASE"
cp "$HERE/Dockerfile.sample" "$BASE/Dockerfile"

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker not available."
  exit 0
fi

echo "-- Building intentionally old image ($IMAGE) ..."
docker build -q -t "$IMAGE" "$BASE" >/dev/null

if ! command -v trivy >/dev/null 2>&1; then
  echo "SKIP: trivy not installed."
  echo "       Install: brew install trivy"
  echo "            or: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
  exit 0
fi

echo
echo "== Pass 1: informational scan (no --exit-code) =="
echo "   This ALWAYS exits 0 regardless of findings."
set +e
trivy image --quiet --severity HIGH,CRITICAL --no-progress "$IMAGE"
rc1=$?
set -e
echo "   exit code: $rc1"

echo
echo "== Pass 2: GATED scan (--severity CRITICAL --exit-code 1) =="
echo "   This EXITS 1 if any CRITICAL is found."
set +e
trivy image --quiet --severity CRITICAL --exit-code 1 --no-progress "$IMAGE"
rc2=$?
set -e
echo "   exit code: $rc2"

echo
if [ "$rc2" -ne 0 ]; then
  echo "GATE TRIGGERED (as expected). In CI this would fail the step."
else
  echo "No CRITICAL found — perhaps your trivy DB is fresh and this base has been patched."
  echo "Try FROM alpine:3.12 or FROM debian:10 to force findings."
fi

echo
echo "To ignore unfixed (less noise):"
echo "  trivy image --severity CRITICAL --exit-code 1 --ignore-unfixed $IMAGE"
