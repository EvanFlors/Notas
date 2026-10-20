#!/usr/bin/env bash
# Validate obs-07-02: fire traffic from many user_ids, scrape /metrics,
# fail if forbidden labels are present or cardinality explodes.
#
# Note: we deliberately do NOT enable `set -o pipefail`; several checks use
# `grep -q` which produces SIGPIPE on short-circuit, which pipefail would
# treat as a failure.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"
APP_DIR="${APP_DIR:-$ACT_DIR/starter}"

if ! python3 -c "import fastapi, uvicorn, prometheus_client, httpx" 2>/dev/null; then
  echo "SKIP: missing python deps (fastapi, uvicorn, prometheus_client, httpx)"
  exit 0
fi

PORT="${PORT:-8789}"
LOG=$(mktemp /tmp/obs07-02.XXXXXX)

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

# Fire traffic from 25 fake user ids over 10 item ids = 250 requests.
# If labels like user_id/item_id are still present, histogram series will blow up.
BASE="http://127.0.0.1:${PORT}" python3 - <<'PY'
import os, httpx
BASE = os.environ["BASE"]
with httpx.Client(timeout=2.0) as c:
    for u in range(25):
        h = {"x-user-id": f"user-{u}"}
        for i in range(10):
            c.get(f"{BASE}/items/{i}", headers=h)
PY

METRICS=$(curl -fs "http://127.0.0.1:${PORT}/metrics")
total_lines=$(echo "$METRICS" | wc -l | awk '{print $1}')

ok=1

# Forbidden labels anywhere.
for bad in user_id request_id trace_id email item_id service_name; do
  if echo "$METRICS" | grep -Eq "[{,]${bad}=\""; then
    echo "FAIL: forbidden label '${bad}' present in /metrics"
    ok=0
  fi
done

# Required labels on the counter.
echo "$METRICS" | grep -q 'http_requests_total{.*method=' \
  || { echo "FAIL: 'method' label missing on http_requests_total"; ok=0; }
echo "$METRICS" | grep -q 'http_requests_total{.*path=' \
  || { echo "FAIL: 'path' label missing on http_requests_total"; ok=0; }

# Need some kind of status (status or status_class).
if ! echo "$METRICS" | grep -Eq 'http_requests_total{.*status(_class)?='; then
  echo "FAIL: no status/status_class label on http_requests_total"
  ok=0
fi

# Templated path only.
if echo "$METRICS" | grep -Eq 'path="/items/[0-9]+"'; then
  echo "FAIL: raw item id leaked into 'path' label"
  ok=0
fi

# Cardinality cap: histogram bucket lines must be bounded.
bucket_lines=$(echo "$METRICS" | grep -c '^http_request_duration_seconds_bucket{' || true)
if [ "$bucket_lines" -gt 200 ]; then
  echo "FAIL: too many histogram bucket series ($bucket_lines) — cardinality still blown"
  ok=0
fi

if [ "$ok" -eq 1 ]; then
  echo "OK: obs-07-02 labels are cardinality-safe (lines=$total_lines, histogram buckets=$bucket_lines)"
  exit 0
else
  echo "---- metrics (head) ----"
  echo "$METRICS" | head -30
  echo "---- totals: lines=$total_lines buckets=$bucket_lines ----"
  exit 1
fi
