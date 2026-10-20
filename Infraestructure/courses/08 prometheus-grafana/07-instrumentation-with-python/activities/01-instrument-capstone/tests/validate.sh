#!/usr/bin/env bash
# Validate obs-07-01: launch the student's starter/app.py (or solution if provided),
# hit endpoints, scrape /metrics, verify required metrics + absence of cardinality bugs.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks use
# `grep -q` which produces SIGPIPE (exit 141) when the matched pipeline is closed
# early; pipefail would spuriously mark those as failures.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"
APP_DIR="${APP_DIR:-$ACT_DIR/starter}"

if ! python3 -c "import fastapi, uvicorn, prometheus_client" 2>/dev/null; then
  echo "SKIP: missing python deps (fastapi, uvicorn, prometheus_client)"
  exit 0
fi

PORT="${PORT:-8788}"
LOG=$(mktemp /tmp/obs07-01.XXXXXX)

cd "$APP_DIR"
python3 -m uvicorn app:app --port "$PORT" --log-level warning > "$LOG" 2>&1 &
PID=$!

cleanup() {
  kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
  rm -f "$LOG"
}
trap cleanup EXIT

for _ in $(seq 1 80); do
  if curl -fs "http://127.0.0.1:${PORT}/health" > /dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

if ! curl -fs "http://127.0.0.1:${PORT}/health" > /dev/null 2>&1; then
  echo "FAIL: app did not come up on port $PORT"
  echo "---- log ----"
  cat "$LOG"
  exit 1
fi

# Exercise the API.
curl -fs "http://127.0.0.1:${PORT}/health" > /dev/null
curl -fs -X POST "http://127.0.0.1:${PORT}/items/" \
     -H 'content-type: application/json' -d '{"name":"alpha"}' > /dev/null
curl -fs "http://127.0.0.1:${PORT}/items/1" > /dev/null
curl -fs -o /dev/null "http://127.0.0.1:${PORT}/items/999" || true  # 404
curl -fs -o /dev/null "http://127.0.0.1:${PORT}/does-not-exist" || true  # 404 unmatched

# Fetch /metrics (allow a brief retry window in case the mount isn't ready yet).
METRICS=""
for _ in $(seq 1 10); do
  METRICS=$(curl -fs "http://127.0.0.1:${PORT}/metrics" || true)
  if [ -n "$METRICS" ]; then break; fi
  sleep 0.5
done

if [ -z "$METRICS" ]; then
  echo "FAIL: /metrics returned nothing. Did you mount it with make_asgi_app?"
  exit 1
fi

ok=1

echo "$METRICS" | grep -q '^# HELP http_requests_total' \
  || { echo "FAIL: Counter 'http_requests_total' missing (check HELP)"; ok=0; }

echo "$METRICS" | grep -q '^# HELP http_request_duration_seconds' \
  || { echo "FAIL: Histogram 'http_request_duration_seconds' missing (check HELP)"; ok=0; }

echo "$METRICS" | grep -q 'http_requests_total{.*method="GET".*path="/items/{item_id}".*status_class="2xx"' \
  || { echo "FAIL: counter line for GET /items/{item_id} 2xx missing (check path templating & status_class)"; ok=0; }

echo "$METRICS" | grep -q 'http_requests_total{.*method="POST".*path="/items/".*status_class="2xx"' \
  || { echo "FAIL: counter line for POST /items/ 2xx missing"; ok=0; }

echo "$METRICS" | grep -q '^http_request_duration_seconds_bucket{' \
  || { echo "FAIL: histogram buckets missing"; ok=0; }

echo "$METRICS" | grep -q 'http_requests_total{.*path="unmatched"' \
  || { echo "FAIL: no 'unmatched' bucket — did you handle non-matching routes?"; ok=0; }

# Cardinality bug: raw item id leaked into labels.
if echo "$METRICS" | grep -Eq 'path="/items/[0-9]+"'; then
  echo "FAIL: raw numeric item id leaked into 'path' label (use templated path)"
  ok=0
fi

if echo "$METRICS" | grep -Eq 'status="(200|404|500)"'; then
  echo "FAIL: raw status code label detected (use status_class='2xx'/'4xx'/'5xx')"
  ok=0
fi

if [ "$ok" -eq 1 ]; then
  echo "OK: obs-07-01 metrics look correct"
  exit 0
else
  echo "---- metrics (first 40 lines) ----"
  echo "$METRICS" | head -40
  exit 1
fi
