#!/usr/bin/env bash
# Push synthetic spans to the collector on localhost:4317 using telemetrygen.
# Arg 1: duration in seconds (default 10).
set -eu
DUR="${1:-10}"
docker run --rm --network otel13ex02_otel13ex02 \
  ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.110.0 \
  traces \
  --otlp-endpoint collector:4317 \
  --otlp-insecure \
  --duration "${DUR}s" \
  --rate 50 \
  --workers 2 \
  --service "otel13-ex02-client"
