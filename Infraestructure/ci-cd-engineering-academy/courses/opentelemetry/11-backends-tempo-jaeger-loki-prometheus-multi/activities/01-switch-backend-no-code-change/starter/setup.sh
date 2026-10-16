#!/usr/bin/env bash
# Starter: lab base with Tempo + Collector + Grafana + trace-gen (no Jaeger yet).
# No `set -o pipefail` on purpose.
set -eu

BASE="${1:-/tmp/otel11-lab01}"
mkdir -p "$BASE"

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
      - tempo

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

cat > "$BASE/tempo-config.yaml" <<'YAML'
server:
  http_listen_port: 3200
distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
ingester:
  trace_idle_period: 10s
  max_block_duration: 1m
compactor:
  compaction:
    block_retention: 1h
storage:
  trace:
    backend: local
    local:
      path: /var/tempo/traces
    wal:
      path: /var/tempo/wal
usage_report:
  reporting_enabled: false
YAML

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
  otlp/tempo:
    endpoint: tempo:4317
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
      exporters: [otlp/tempo, debug]
YAML

cat > "$BASE/grafana-datasources.yaml" <<'YAML'
apiVersion: 1
datasources:
  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    isDefault: true
YAML

echo "Starter copied to $BASE"
echo "Next: cd $BASE && docker compose up -d"
echo "Then follow README.md to swap Tempo for Jaeger."
