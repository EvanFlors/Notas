#!/usr/bin/env bash
# Validate otel-04-01: launch student's app (or solution), fire checkout requests,
# capture console-exported spans from stdout and assert the expected names,
# attributes, and ERROR status.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# use `grep -q` with pipes that may close early (SIGPIPE / exit 141); pipefail
# would spuriously mark those as failures.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"
APP_DIR="${APP_DIR:-$ACT_DIR/starter}"

if ! python3 -c "import fastapi, uvicorn" 2>/dev/null; then
  echo "SKIP: missing fastapi/uvicorn"
  exit 0
fi

if ! python3 -c "import opentelemetry.sdk" 2>/dev/null; then
  echo "SKIP: missing opentelemetry-sdk"
  exit 0
fi

# Does the target app have any OTel setup? If starter is untouched and the
# student has not implemented anything, surface a helpful hint.
if ! grep -q "TracerProvider" "$APP_DIR/app.py"; then
  echo "FAIL: $APP_DIR/app.py has no TracerProvider — did you configure tracing?"
  exit 1
fi

PORT="${PORT:-8791}"
LOG=$(mktemp /tmp/otel04-01.XXXXXX)

cd "$APP_DIR"

# Force console exporter by UNsetting any OTLP endpoint for this run.
unset OTEL_EXPORTER_OTLP_ENDPOINT || true

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

# Happy path.
curl -fs -X POST "http://127.0.0.1:${PORT}/checkout" \
  -H 'content-type: application/json' \
  -d '{"cart_id":"c1","user_id":"u1","items_count":2,"total_cents":4999}' > /dev/null

# Over-limit → payment.charge should emit ERROR status.
curl -fs -o /dev/null -X POST "http://127.0.0.1:${PORT}/checkout" \
  -H 'content-type: application/json' \
  -d '{"cart_id":"c2","user_id":"u2","items_count":1,"total_cents":200000}' || true

# Trigger shutdown so BatchSpanProcessor flushes to stdout.
kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true

ok=1

for name in "checkout.process" "inventory.reserve" "payment.charge"; do
  if ! grep -q "\"name\": \"$name\"" "$LOG" && ! grep -q "\"name\":\"$name\"" "$LOG"; then
    echo "FAIL: span '$name' not found in console output"
    ok=0
  fi
done

if ! grep -q "capstone-checkout" "$LOG"; then
  echo "FAIL: service.name 'capstone-checkout' not found in resource attributes"
  ok=0
fi

if ! grep -q "checkout.cart_id" "$LOG"; then
  echo "FAIL: attribute 'checkout.cart_id' not found"
  ok=0
fi

if ! grep -q "payment.amount_cents" "$LOG"; then
  echo "FAIL: attribute 'payment.amount_cents' not found"
  ok=0
fi

# ERROR status for the over-limit payment.
if ! grep -q "ERROR" "$LOG"; then
  echo "FAIL: no ERROR status recorded (over-limit payment should set it)"
  ok=0
fi

if ! grep -q "amount above limit" "$LOG"; then
  echo "FAIL: exception message 'amount above limit' not recorded"
  ok=0
fi

if [ "$ok" -eq 1 ]; then
  echo "OK: otel-04-01 — provider configured and business spans emitted"
  exit 0
else
  echo "---- log (first 120 lines) ----"
  head -120 "$LOG"
  exit 1
fi
