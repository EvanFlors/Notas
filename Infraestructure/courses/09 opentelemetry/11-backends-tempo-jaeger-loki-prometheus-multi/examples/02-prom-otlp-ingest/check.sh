#!/usr/bin/env bash
# Smoke test for example 02: Prometheus OTLP ingest.
# No `set -o pipefail` on purpose (grep -q on piped output).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not installed"; exit 0
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "SKIP: 'docker compose' plugin not available"; exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker daemon not running"; exit 0
fi

echo "== Starting stack =="
docker compose up -d

echo "== Waiting for Prometheus ready (up to 60s) =="
ready=0
for i in $(seq 1 30); do
  if curl -fsS http://localhost:9090/-/ready >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 2
done
if [ "$ready" -ne 1 ]; then
  echo "FAIL: Prometheus not ready"
  docker compose logs prometheus | tail -40
  docker compose down -v
  exit 1
fi

echo "== Waiting for 'gen' metric in Prometheus (up to 90s) =="
got=0
for i in $(seq 1 45); do
  resp="$(curl -fsS -G \
    --data-urlencode 'query=gen' \
    http://localhost:9090/api/v1/query 2>/dev/null || true)"
  if echo "$resp" | grep -q '"result":\[{'; then
    got=1; break
  fi
  sleep 2
done

if [ "$got" -eq 1 ]; then
  echo "OK: Prometheus has 'gen' metric from OTLP ingest"
  rc=0
else
  echo "FAIL: no 'gen' metric after 90s"
  echo "---- Collector metrics (exporter) ----"
  curl -fsS http://localhost:8888/metrics 2>/dev/null | grep -E 'otelcol_exporter_(sent|send_failed)_metric_points' || true
  echo "---- Collector logs ----"
  docker compose logs otel-collector | tail -30
  rc=1
fi

echo "== Cleanup =="
docker compose down -v
exit $rc
