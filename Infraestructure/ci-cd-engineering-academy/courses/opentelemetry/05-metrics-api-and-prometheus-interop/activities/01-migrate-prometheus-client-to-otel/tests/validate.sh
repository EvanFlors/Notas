#!/usr/bin/env bash
# Validate otel-05-01: launch the migrated Flask app, hit endpoints, scrape
# /metrics and verify OTel metrics appear with Prometheus-compatible names.
#
# NOTE: we deliberately do NOT enable `set -o pipefail` because several checks
# use `grep -q` which can produce SIGPIPE (exit 141) when the matched pipeline
# is closed early; pipefail would spuriously mark those as failures.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"
APP_DIR="${APP_DIR:-$ACT_DIR/solution}"

if ! python3 -c "import flask" 2>/dev/null; then
  echo "SKIP: flask not installed"; exit 0
fi
if ! python3 -c "from opentelemetry.exporter.prometheus import PrometheusMetricReader" 2>/dev/null; then
  echo "SKIP: opentelemetry-exporter-prometheus not installed"; exit 0
fi

APP_PORT="${APP_PORT:-8089}"
METRICS_PORT="${METRICS_PORT:-9469}"
LOG=$(mktemp /tmp/otel05-01.XXXXXX)

cleanup() {
  if [ -n "${PID:-}" ]; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
  fi
  rm -f "$LOG"
}
trap cleanup EXIT

cd "$APP_DIR"
APP_PORT="$APP_PORT" METRICS_PORT="$METRICS_PORT" \
  python3 app.py > "$LOG" 2>&1 &
PID=$!

for _ in $(seq 1 80); do
  if curl -fs "http://127.0.0.1:${APP_PORT}/hello" > /dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

if ! curl -fs "http://127.0.0.1:${APP_PORT}/hello" > /dev/null 2>&1; then
  echo "FAIL: app did not come up on :$APP_PORT"
  echo "---- log ----"; cat "$LOG"; exit 1
fi

# Exercise the API so metrics have data points.
for _ in 1 2 3; do curl -fs "http://127.0.0.1:${APP_PORT}/hello" > /dev/null; done
curl -fs "http://127.0.0.1:${APP_PORT}/slow"  > /dev/null
curl -fs -o /dev/null "http://127.0.0.1:${APP_PORT}/missing" || true

# Scrape /metrics (small retry window for the reader to flush once).
METRICS=""
for _ in $(seq 1 10); do
  METRICS=$(curl -fs "http://127.0.0.1:${METRICS_PORT}/metrics" || true)
  if [ -n "$METRICS" ] && echo "$METRICS" | grep -q 'http_server_requests'; then
    break
  fi
  sleep 0.3
done

if [ -z "$METRICS" ]; then
  echo "FAIL: /metrics returned nothing on :$METRICS_PORT"; exit 1
fi

ok=1
echo "$METRICS" | grep -q 'http_server_requests_total' \
  || { echo "FAIL: counter 'http_server_requests_total' missing"; ok=0; }
echo "$METRICS" | grep -q 'http_server_request_duration_seconds_bucket' \
  || { echo "FAIL: histogram buckets 'http_server_request_duration_seconds_bucket' missing"; ok=0; }
echo "$METRICS" | grep -q 'http_request_method="GET"' \
  || { echo "FAIL: semconv attribute 'http.request.method' missing"; ok=0; }
echo "$METRICS" | grep -q 'http_route="/hello"' \
  || { echo "FAIL: attribute 'http.route' for /hello missing"; ok=0; }

if [ "$ok" -eq 1 ]; then
  echo "OK: otel-05-01 — OTel metrics exposed as Prometheus text format"
  exit 0
else
  echo "---- metrics (first 60 lines) ----"
  echo "$METRICS" | head -60
  exit 1
fi
