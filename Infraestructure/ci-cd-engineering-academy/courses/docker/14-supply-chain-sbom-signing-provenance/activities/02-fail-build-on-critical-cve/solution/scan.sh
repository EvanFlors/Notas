#!/usr/bin/env bash
# dkr-14-02 — reference solution. Trivy gate on CRITICAL CVEs.
# Note: no `set -o pipefail`.
set -eu

IMAGE="dkr-14-02-vuln:v1"
BASE="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -f "$BASE/Dockerfile" ]; then
  BASE="/tmp/dkr-14-02"
fi

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "FAIL: docker not available."
  exit 2
fi
if ! command -v trivy >/dev/null 2>&1; then
  echo "FAIL: trivy not installed. See README §4."
  exit 2
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "-- building $IMAGE ..."
  docker build -q -t "$IMAGE" "$BASE" >/dev/null
fi

echo "== trivy gate (CRITICAL) =="
set +e
trivy image --no-progress --severity CRITICAL --exit-code 1 "$IMAGE"
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  echo "GATE: OK — no CRITICAL vulnerabilities."
else
  echo "GATE: FAIL — CRITICAL vulnerabilities present. Blocking release."
fi
exit $rc
