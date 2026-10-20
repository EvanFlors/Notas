#!/usr/bin/env bash
# Reference solution: swap Tempo -> Jaeger in-place without touching the app.
# No `set -o pipefail` on purpose.
set -eu

BASE="${1:-/tmp/otel11-lab01}"
if [ ! -d "$BASE" ]; then
  echo "ERROR: run starter/setup.sh $BASE first"
  exit 1
fi

# Capture the app container id BEFORE touching anything, if it is up.
if docker inspect -f '{{.Id}}' lab01-trace-gen >/dev/null 2>&1; then
  docker inspect -f '{{.Id}}' lab01-trace-gen > /tmp/trace-gen-id-before.txt
  echo "Recorded app container id: $(cat /tmp/trace-gen-id-before.txt)"
fi

# Rewrite docker-compose.yaml: add Jaeger service, keep everything else.
cat > "$BASE/docker-compose.yaml" <<'YAML'
services:
  tempo:
    image: grafana/tempo:2.6.0
    container_name: lab01-tempo
    command: ["-config.file=/etc/tempo/tempo-config.yaml"]
    ports:
      - "3200:3200"
    volumes:
      - ./tempo-config.yaml:/etc/tempo/tempo-config.yaml:ro
      - tempo-data:/var/tempo

  jaeger:
    image: jaegertracing/all-in-one:1.60
    container_name: lab01-jaeger
    environment:
      COLLECTOR_OTLP_ENABLED: "true"
    ports:
      - "16686:16686"
      - "14317:4317"

  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.111.0
    container_name: lab01-otelcol
    command: ["--config=/etc/otelcol/config.yaml"]
    ports:
      - "4317:4317"
      - "4318:4318"
      - "8888:8888"
    volumes:
      - ./otel-collector-config.yaml:/etc/otelcol/config.yaml:ro
    depends_on:
      - jaeger

  grafana:
    image: grafana/grafana:11.3.0
    container_name: lab01-grafana
    environment:
      GF_AUTH_ANONYMOUS_ENABLED: "true"
      GF_AUTH_ANONYMOUS_ORG_ROLE: Admin
      GF_SECURITY_ADMIN_PASSWORD: admin
    ports:
      - "3000:3000"
    volumes:
      - ./grafana-datasources.yaml:/etc/grafana/provisioning/datasources/datasources.yaml:ro

  trace-gen:
    image: ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.111.0
    container_name: lab01-trace-gen
    command:
      - traces
      - --otlp-endpoint=otel-collector:4317
      - --otlp-insecure
      - --service=trace-gen
      - --rate=5
      - --duration=24h
    depends_on:
      - otel-collector

volumes:
  tempo-data:
YAML

# Rewrite Collector config: pipeline traces -> jaeger only (Tempo stays unused).
cat > "$BASE/otel-collector-config.yaml" <<'YAML'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 1s
    send_batch_size: 512
  memory_limiter:
    check_interval: 2s
    limit_mib: 256

exporters:
  otlp/jaeger:
    endpoint: jaeger:4317
    tls:
      insecure: true
  debug:
    verbosity: basic

service:
  telemetry:
    metrics:
      level: detailed
      readers:
        - pull:
            exporter:
              prometheus:
                host: 0.0.0.0
                port: 8888
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/jaeger, debug]
YAML

cd "$BASE"
# Bring up new service (Jaeger) + force recreate only the Collector.
# The app (trace-gen) is NOT in this list and keeps its container id.
docker compose up -d jaeger
docker compose up -d --force-recreate otel-collector

echo
echo "Done. Verify with:"
echo "  bash <repo>/activities/01-switch-backend-no-code-change/tests/validate.sh $BASE"
