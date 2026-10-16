#!/usr/bin/env bash
# Smoke test: launches app, hits endpoints, greps /metrics, kills app.
set -eu

cd "$(dirname "$0")"

if ! python3 -c "import fastapi, uvicorn, prometheus_client" 2>/dev/null; then
  echo "SKIP: missing python deps (fastapi, uvicorn, prometheus_client)"
  exit 0
fi

PORT="${PORT:-8765}"
LOG=$(mktemp /tmp/obs07-ex01.XXXXXX)
trap 'rm -f "$LOG"' EXIT

python3 -m uvicorn app:app --port "$PORT" --log-level warning > "$LOG" 2>&1 &
PID=$!

cleanup() {
  kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
}
trap 'cleanup; rm -f "$LOG"' EXIT

# Wait for readiness
for _ in $(seq 1 80); do
  if curl -fs "http://127.0.0.1:${PORT}/health" > /dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

curl -fs "http://127.0.0.1:${PORT}/health" > /dev/null
curl -fs "http://127.0.0.1:${PORT}/work" > /dev/null

METRICS=$(curl -fs "http://127.0.0.1:${PORT}/metrics")

ok=1
echo "$METRICS" | grep -q '^demo_requests_total{' || { echo "FAIL: demo_requests_total missing"; ok=0; }
echo "$METRICS" | grep -q '^demo_request_duration_seconds_bucket{' || { echo "FAIL: demo_request_duration_seconds_bucket missing"; ok=0; }

if [ "$ok" -eq 1 ]; then
  echo "OK: example 01 metrics exposed"
  exit 0
else
  echo "---- metrics (first 40 lines) ----"
  echo "$METRICS" | head -40
  exit 1
fi
