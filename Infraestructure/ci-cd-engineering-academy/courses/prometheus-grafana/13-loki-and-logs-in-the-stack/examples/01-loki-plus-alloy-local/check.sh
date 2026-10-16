#!/usr/bin/env bash
# Smoke test for example 01: verify Loki is up and has logs for {app="demo-app"}.
# Deliberately NO `set -o pipefail` — some pipes use `grep -q` which can SIGPIPE
# the producer and would be reported as spurious failures.
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

echo "== Waiting for Loki ready =="
ready=0
for i in $(seq 1 30); do
  if curl -fsS http://localhost:3100/ready >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 2
done
if [ "$ready" -ne 1 ]; then
  echo "FAIL: Loki did not become ready in 60s"
  docker compose logs loki | tail -40
  docker compose down -v
  exit 1
fi

echo "== Waiting for demo-app logs to flow (up to 60s) =="
got=0
for i in $(seq 1 30); do
  # query logs from last 5 min for stream app=demo-app
  resp="$(curl -fsS -G \
    --data-urlencode 'query={app="demo-app"}' \
    --data-urlencode 'limit=5' \
    'http://localhost:3100/loki/api/v1/query_range' 2>/dev/null || true)"
  if echo "$resp" | grep -q '"values"'; then
    got=1; break
  fi
  sleep 2
done

if [ "$got" -eq 1 ]; then
  echo "OK: Loki is receiving demo-app logs"
  rc=0
else
  echo "FAIL: no demo-app logs in Loki after 60s"
  docker compose logs alloy | tail -20
  rc=1
fi

echo "== Cleanup =="
docker compose down -v
exit $rc
