#!/usr/bin/env bash
# Smoke test for the RED middleware example.
set -eu

cd "$(dirname "$0")"

if ! python3 -c "import fastapi, uvicorn, prometheus_client" 2>/dev/null; then
  echo "SKIP: missing python deps (fastapi, uvicorn, prometheus_client)"
  exit 0
fi

PORT="${PORT:-8766}"
LOG=$(mktemp /tmp/obs07-ex02.XXXXXX)

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

curl -fs "http://127.0.0.1:${PORT}/items/1" > /dev/null
curl -fs "http://127.0.0.1:${PORT}/items/2" > /dev/null
curl -fs -o /dev/null "http://127.0.0.1:${PORT}/items/-1" || true  # 400
curl -fs -o /dev/null "http://127.0.0.1:${PORT}/does-not-exist" || true  # 404

METRICS=$(curl -fs "http://127.0.0.1:${PORT}/metrics")

ok=1
echo "$METRICS" | grep -q 'http_requests_total{.*path="/items/{item_id}".*status_class="2xx"' \
  || { echo "FAIL: 2xx counter missing for templated items path"; ok=0; }
echo "$METRICS" | grep -q 'http_requests_total{.*path="/items/{item_id}".*status_class="4xx"' \
  || { echo "FAIL: 4xx counter missing for templated items path"; ok=0; }
echo "$METRICS" | grep -q 'http_requests_total{.*path="unmatched"' \
  || { echo "FAIL: unmatched bucket missing"; ok=0; }
echo "$METRICS" | grep -q '^http_request_duration_seconds_bucket{' \
  || { echo "FAIL: duration histogram missing"; ok=0; }
echo "$METRICS" | grep -q '^http_requests_inflight{method="GET"}' \
  || { echo "FAIL: inflight gauge missing"; ok=0; }

if ! echo "$METRICS" | grep -Eq 'path="/items/[0-9]+"'; then
  :
else
  echo "FAIL: raw item id leaked into path label (cardinality bug)"
  ok=0
fi

if [ "$ok" -eq 1 ]; then
  echo "OK: example 02 RED middleware exposes correct metrics"
  exit 0
else
  echo "---- metrics (head) ----"
  echo "$METRICS" | head -40
  exit 1
fi
