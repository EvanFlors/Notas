#!/usr/bin/env bash
# Bootstrap the starter directory for obs-11-01.
# Creates <base>/ with:
#   docker-compose.yml   -- prometheus + victoriametrics + node-exporter
#   prometheus.yml       -- scrape OK, remote_write MISSING (student must add it)
#
# Usage:  bash starter/bootstrap.sh [BASE_DIR]
# Default BASE_DIR = /tmp/obs11-vm

set -eu

BASE="${1:-/tmp/obs11-vm}"

if [ -d "$BASE" ]; then
  echo "Removing existing $BASE"
  rm -rf "$BASE"
fi

mkdir -p "$BASE"
cd "$BASE"

cat > docker-compose.yml <<'YAML'
name: obs11-vm

services:
  victoriametrics:
    image: victoriametrics/victoria-metrics:v1.102.1
    container_name: obs11-vm
    ports:
      - "8428:8428"
    command:
      - "--storageDataPath=/storage"
      - "--retentionPeriod=90d"
      - "--httpListenAddr=:8428"
    volumes:
      - vm-data:/storage
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:v1.8.2
    container_name: obs11-node
    ports:
      - "9100:9100"
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:v2.54.1
    container_name: obs11-prom
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prom-data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--storage.tsdb.retention.time=2h"
      - "--web.enable-remote-write-receiver"
    depends_on:
      - victoriametrics
      - node-exporter
    restart: unless-stopped

volumes:
  vm-data:
  prom-data:
YAML

cat > prometheus.yml <<'YAML'
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

# TODO (actividad): añadir aquí la sección `remote_write` apuntando a
# http://victoriametrics:8428/api/v1/write, con queue_config y
# write_relabel_configs que descarte go_* y process_*.
YAML

echo "Starter ready at: $BASE"
echo "Files:"
ls -1 "$BASE"
echo
echo "Next: edit prometheus.yml to add remote_write, then: docker compose up -d"
