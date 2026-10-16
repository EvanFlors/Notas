#!/usr/bin/env bash
# Smoke test for example 01: zero-code auto-instrumentation via opentelemetry-instrument.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks use
# `grep -q` with pipes that may close early (SIGPIPE / exit 141); pipefail would
# spuriously mark those as failures.

set -eu

cd "$(dirname "$0")"

if ! python3 -c "import fastapi, uvicorn, httpx" 2>/dev/null; then
  echo "SKIP: missing python deps (fastapi, uvicorn, httpx)"
  exit 0
fi

if ! python3 -c "import opentelemetry.instrumentation.fastapi, opentelemetry.sdk" 2>/dev/null; then
  echo "SKIP: missing opentelemetry-instrumentation-fastapi (install opentelemetry-distro + instrumentation packages)"
  exit 0
fi

if ! command -v opentelemetry-instrument >/dev/null 2>&1; then
  echo "SKIP: opentelemetry-instrument CLI not on PATH (install opentelemetry-distro)"
  exit 0
fi

PORT="${PORT:-8781}"
LOG=$(mktemp /tmp/otel04-ex01.XXXXXX)

cleanup() {
  if [ -n "${PID:-}" ]; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
  fi
  rm -f "$LOG"
}
trap cleanup EXIT

OTEL_TRACES_EXPORTER=console \
OTEL_METRICS_EXPORTER=none \
OTEL_LOGS_EXPORTER=none \
OTEL_SERVICE_NAME=example-01-auto \
OTEL_PYTHON_LOG_CORRELATION=false \
  opentelemetry-instrument python3 -m uvicorn app:app --port "$PORT" --log-level warning > "$LOG" 2>&1 &
PID=$!

# Wait for readiness.
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

curl -fs "http://127.0.0.1:${PORT}/health" > /dev/null
curl -fs "http://127.0.0.1:${PORT}/work" > /dev/null || true

# Give BatchSpanProcessor a moment to flush.
sleep 2

ok=1
# Console exporter prints JSON per span; look for FastAPI SERVER span attributes.
if grep -q '"name": "GET /health"' "$LOG" || grep -q '"name":"GET /health"' "$LOG"; then
  :
else
  echo "FAIL: no span named 'GET /health' in console output"
  ok=0
fi

if grep -q 'service.name' "$LOG"; then
  :
else
  echo "FAIL: no 'service.name' resource attribute in console output"
  ok=0
fi

if [ "$ok" -eq 1 ]; then
  echo "OK: example 01 — auto-instrumentation emitted FastAPI SERVER spans"
  exit 0
else
  echo "---- log (first 60 lines) ----"
  head -60 "$LOG"
  exit 1
fi
