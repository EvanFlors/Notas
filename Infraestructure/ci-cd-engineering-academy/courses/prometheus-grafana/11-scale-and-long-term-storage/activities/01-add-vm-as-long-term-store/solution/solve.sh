#!/usr/bin/env bash
# Apply the solution: rewrite prometheus.yml with the remote_write section
# and bring the stack up.
#
# Usage: bash solution/solve.sh [BASE_DIR]
# Default BASE_DIR = /tmp/obs11-vm

set -eu

BASE="${1:-/tmp/obs11-vm}"

if [ ! -f "$BASE/prometheus.yml" ]; then
  echo "ERROR: $BASE/prometheus.yml not found. Run starter/bootstrap.sh first."
  exit 1
fi

cat > "$BASE/prometheus.yml" <<'YAML'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: local-demo
    replica: a

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['localhost:9090']

  - job_name: node
    static_configs:
      - targets: ['node-exporter:9100']

remote_write:
  - url: http://victoriametrics:8428/api/v1/write
    queue_config:
      capacity: 10000
      max_shards: 30
      min_shards: 1
      max_samples_per_send: 2000
      batch_send_deadline: 5s
    write_relabel_configs:
      - source_labels: [__name__]
        regex: '(go_|process_).*'
        action: drop
YAML

echo "Wrote $BASE/prometheus.yml with remote_write."

if command -v docker >/dev/null 2>&1; then
  echo "Bringing stack up..."
  (cd "$BASE" && docker compose up -d)
  echo "Stack up. Give it ~20s then run tests/validate.sh $BASE"
else
  echo "docker not found; skipping compose up. The config is in place."
fi
