#!/usr/bin/env bash
# Push 10 spans with planted PII via telemetrygen, which supports custom attributes.
set -eu

docker run --rm --network otel13ex03_otel13ex03 \
  ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.110.0 \
  traces \
  --otlp-endpoint collector:4317 \
  --otlp-insecure \
  --traces 5 \
  --service "otel13-ex03-client" \
  --otlp-attributes "user.email=\"alice@example.com\"" \
  --otlp-attributes "user.password=\"hunter2-not-a-real-secret\"" \
  --otlp-attributes "http.request.header.authorization=\"Bearer dev-token-not-a-secret\"" \
  --otlp-attributes "http.request.header.cookie=\"session=abc123\"" \
  --otlp-attributes "credit_card=\"4111111111111111\"" \
  --otlp-attributes "ssn=\"123-45-6789\"" \
  --otlp-attributes "http.url=\"https://api.example.com/u/bob@example.com\"" \
  --otlp-attributes "url.query=\"token=shouldberedacted&q=normal\""
