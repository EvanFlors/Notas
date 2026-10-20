#!/usr/bin/env bash
# Smoke-test the MWMBR alerts with promtool. Uses `prom/prometheus` via Docker.
#
# Note: we intentionally do NOT enable `set -o pipefail` because some checks
# rely on `grep -q` which can trigger SIGPIPE (141) that pipefail would misread
# as failures.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
PROM_IMAGE="prom/prometheus:v2.54.1"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not available"
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable"
  exit 0
fi

echo "==> promtool check rules"
docker run --rm --entrypoint promtool -v "$HERE:/w" -w /w "$PROM_IMAGE" \
  check rules rules.yaml

echo "==> promtool test rules"
docker run --rm --entrypoint promtool -v "$HERE:/w" -w /w "$PROM_IMAGE" \
  test rules test.yaml

echo "OK: MWMBR alerts valid and fire as expected"
