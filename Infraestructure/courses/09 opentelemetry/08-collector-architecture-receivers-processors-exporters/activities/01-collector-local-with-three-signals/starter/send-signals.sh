#!/usr/bin/env bash
# Send a small burst of traces, metrics and logs to the local Collector via OTLP gRPC.
# Uses the official telemetrygen tool image.
set -eu

ENDPOINT="${ENDPOINT:-host.docker.internal:4317}"
IMAGE="${TELEMETRYGEN_IMAGE:-ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest}"

# On Linux, host.docker.internal does not resolve by default; use --network host.
NET_ARGS=()
if [ "$(uname -s)" = "Linux" ]; then
  NET_ARGS=(--network host)
  ENDPOINT="${ENDPOINT_LINUX:-localhost:4317}"
fi

send() {
  local signal="$1"
  echo "-> sending $signal to $ENDPOINT"
  # Each subcommand has its own count flag: --traces / --metrics / --logs.
  docker run --rm "${NET_ARGS[@]}" "$IMAGE" "$signal" \
    --otlp-insecure \
    --otlp-endpoint "$ENDPOINT" \
    "--${signal}" 20 \
    --duration 2s \
    --service "demo-service" 2>&1 | tail -n 3 || true
}

send traces
send metrics
send logs

echo "Done. Check /tmp/otel-lab/*.jsonl"
