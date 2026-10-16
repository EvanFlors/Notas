#!/usr/bin/env bash
# Validate the generated (or expected) rules with promtool.
#
# Note: no `set -o pipefail` here — we use `grep -q` further down and SIGPIPE
# (exit 141) would be misreported as failure.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
PROM_IMAGE="prom/prometheus:v2.54.1"

TARGET="generated-rules.yaml"
if [ ! -f "$HERE/$TARGET" ]; then
  TARGET="expected-rules.yaml"
  echo "generated-rules.yaml not found; falling back to $TARGET"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not available"
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable"
  exit 0
fi

echo "==> promtool check rules $TARGET"
docker run --rm --entrypoint promtool -v "$HERE:/w" -w /w "$PROM_IMAGE" \
  check rules "$TARGET"
echo "OK"
