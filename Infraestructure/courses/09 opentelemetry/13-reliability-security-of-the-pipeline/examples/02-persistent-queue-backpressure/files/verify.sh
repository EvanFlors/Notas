#!/usr/bin/env bash
# Verify persistent queue survives collector restart with backend down.
# No pipefail (we grep over /metrics output that may exit early).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
BASE="${BASE_DIR:-/tmp/otel13-ex02}"
mkdir -p "$BASE/queue"

if ! command -v docker >/dev/null 2>&1; then echo "SKIP: docker no instalado"; exit 0; fi
if ! docker info >/dev/null 2>&1; then echo "SKIP: dockerd no accesible"; exit 0; fi

cd "$HERE"
docker compose up -d --force-recreate
sleep 6

echo "== Baseline: enviar carga con backend arriba =="
bash generate-load.sh 5 >/dev/null 2>&1 || { echo "FAIL: telemetrygen"; exit 1; }
sleep 3

echo "== Parar backend; enviar mas carga =="
docker compose stop backend
sleep 2
bash generate-load.sh 8 >/dev/null 2>&1 || true
sleep 3

queue_before=$(curl -s localhost:8888/metrics | awk '/^otelcol_exporter_queue_size/{print $2; exit}')
echo "  queue_size tras caida backend: ${queue_before:-0}"

echo "== Reiniciar collector; queue debe persistir =="
docker compose restart collector
sleep 8

queue_after=$(curl -s localhost:8888/metrics | awk '/^otelcol_exporter_queue_size/{print $2; exit}')
echo "  queue_size tras restart: ${queue_after:-0}"

# WAL files on disk?
wal_files=$(ls "$BASE/queue" 2>/dev/null | wc -l | tr -d ' ')
if [ "$wal_files" -gt 0 ]; then
  echo "  OK: hay $wal_files archivos en $BASE/queue (persistencia confirmada)"
else
  echo "  FAIL: no hay archivos de queue en $BASE/queue" >&2
  exit 1
fi

echo "== Levantar backend; queue debe drenarse =="
docker compose start backend
sleep 15

queue_final=$(curl -s localhost:8888/metrics | awk '/^otelcol_exporter_queue_size/{print $2; exit}')
echo "  queue_size final: ${queue_final:-0}"

sent=$(curl -s localhost:8888/metrics | awk '/^otelcol_exporter_sent_spans/{s+=$2} END{print s+0}')
echo "  otelcol_exporter_sent_spans total: $sent"

if [ "$sent" -gt 0 ]; then
  echo "== OK: persistent queue + recovery verificado =="
else
  echo "FAIL: no se entregaron spans tras recuperacion" >&2
  exit 1
fi
