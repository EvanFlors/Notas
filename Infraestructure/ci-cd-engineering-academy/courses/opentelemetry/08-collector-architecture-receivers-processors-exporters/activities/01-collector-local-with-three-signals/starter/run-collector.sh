#!/usr/bin/env bash
# Launch the OTel Collector (contrib) with the starter config.
# Output directory is /tmp/otel-lab on the host.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${OUT_DIR:-/tmp/otel-lab}"
NAME="${COLLECTOR_NAME:-otel-lab-collector}"
IMAGE="${COLLECTOR_IMAGE:-otel/opentelemetry-collector-contrib:latest}"

mkdir -p "$OUT_DIR"
# Ensure the container (which runs as user 10001) can write to the bind mount.
chmod 777 "$OUT_DIR"

# Remove any previous instance.
docker rm -f "$NAME" >/dev/null 2>&1 || true

echo "Starting collector '$NAME' on 4317/tcp and 4318/tcp..."
echo "Output JSON lines will land under $OUT_DIR"
docker run --rm \
  --name "$NAME" \
  -p 4317:4317 -p 4318:4318 \
  -v "$SCRIPT_DIR/config.yaml:/etc/otelcol/config.yaml:ro" \
  -v "$OUT_DIR:/out" \
  "$IMAGE" \
  --config=/etc/otelcol/config.yaml
