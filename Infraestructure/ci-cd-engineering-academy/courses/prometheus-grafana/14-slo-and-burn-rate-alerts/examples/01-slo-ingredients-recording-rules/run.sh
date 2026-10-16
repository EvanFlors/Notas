#!/usr/bin/env bash
# Smoke-test the SLO ingredient recording rules with promtool.
#
# Note: we intentionally do NOT enable `set -o pipefail` because some checks
# below pipe to `grep -q` and git/other producers can hit SIGPIPE (141) which
# pipefail would mark as a failure. We rely on explicit `|| rc=1` chaining.

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

echo "OK: ingredient rules valid and tests pass"
