#!/usr/bin/env bash
# Generate PrometheusRule from `slo.yaml` using Sloth. SKIPs cleanly if Docker
# or the Sloth image are not available.
#
# Note: no `set -o pipefail` — we rely on `grep -q` elsewhere and SIGPIPE 141
# would be misreported as failure.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
SLOTH_IMAGE="ghcr.io/slok/sloth:v0.11.0"
OUT="$HERE/generated-rules.yaml"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not available — see expected-rules.yaml for reference output"
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not reachable — see expected-rules.yaml"
  exit 0
fi

if ! docker pull "$SLOTH_IMAGE" >/dev/null 2>&1; then
  echo "SKIP: cannot pull $SLOTH_IMAGE — see expected-rules.yaml for reference output"
  exit 0
fi

echo "==> sloth generate"
docker run --rm -v "$HERE:/w" -w /w "$SLOTH_IMAGE" \
  generate -i slo.yaml -o generated-rules.yaml

echo "==> head of generated-rules.yaml:"
head -40 "$OUT" || true
echo "OK: $OUT written"
