#!/usr/bin/env bash
# Smoke test for example 01: verify Collector forwards traces to Tempo.
# Deliberately NO `set -o pipefail` — some checks use `grep -q` on piped
# outputs; pipefail would spuriously fail on SIGPIPE from the producer.
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

echo "== Waiting for Tempo /ready (up to 60s) =="
ready=0
for i in $(seq 1 30); do
  if curl -fsS http://localhost:3200/ready >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 2
done
if [ "$ready" -ne 1 ]; then
  echo "FAIL: Tempo did not become ready"
  docker compose logs tempo | tail -40
  docker compose down -v
  exit 1
fi

echo "== Waiting for traces to flow into Tempo (up to 60s) =="
got=0
for i in $(seq 1 30); do
  resp="$(curl -fsS -G \
    --data-urlencode 'tags=service.name=trace-gen' \
    --data-urlencode 'limit=5' \
    'http://localhost:3200/api/search' 2>/dev/null || true)"
  if echo "$resp" | grep -q '"traceID"'; then
    got=1; break
  fi
  sleep 2
done

if [ "$got" -eq 1 ]; then
  echo "OK: Tempo received trace-gen traces"
  rc=0
else
  echo "FAIL: no traces in Tempo after 60s"
  docker compose logs otel-collector | tail -30
  rc=1
fi

echo "== Cleanup =="
docker compose down -v
exit $rc
