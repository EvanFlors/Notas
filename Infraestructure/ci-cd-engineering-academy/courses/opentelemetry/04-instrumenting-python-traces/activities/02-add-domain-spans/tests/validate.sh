#!/usr/bin/env bash
# Validate otel-04-02: ensure student added the three domain spans with correct
# names, attributes and ERROR status, without touching the pre-existing middleware.
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

ok=1

# Static checks: the student must have added the three domain span names in source.
for name in "checkout.process" "inventory.reserve" "payment.charge"; do
  if ! grep -q "\"$name\"" "$APP_DIR/app.py"; then
    echo "FAIL: span name '$name' not present in $APP_DIR/app.py"
    ok=0
  fi
done

# Middleware must still exist and be untouched (name intact).
if ! grep -q "http.server.request" "$APP_DIR/app.py"; then
  echo "FAIL: pre-existing middleware span 'http.server.request' removed — do not modify the middleware"
  ok=0
fi

if [ "$ok" -ne 1 ]; then
  echo "---- aborting runtime checks ----"
  exit 1
fi

PORT="${PORT:-8792}"
LOG=$(mktemp /tmp/otel04-02.XXXXXX)

cd "$APP_DIR"
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

curl -fs -X POST "http://127.0.0.1:${PORT}/checkout" \
  -H 'content-type: application/json' \
  -d '{"cart_id":"c1","user_id":"u1","items_count":2,"total_cents":4999}' > /dev/null

curl -fs -o /dev/null -X POST "http://127.0.0.1:${PORT}/checkout" \
  -H 'content-type: application/json' \
  -d '{"cart_id":"c2","user_id":"u2","items_count":1,"total_cents":200000}' || true

# Flush: shutdown triggers BatchSpanProcessor.shutdown via on_event handler.
kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true

for name in "checkout.process" "inventory.reserve" "payment.charge" "http.server.request"; do
  if ! grep -q "\"name\": \"$name\"" "$LOG" && ! grep -q "\"name\":\"$name\"" "$LOG"; then
    echo "FAIL: expected span '$name' in console output"
    ok=0
  fi
done

for attr in "checkout.cart_id" "inventory.items.count" "payment.amount_cents" "payment.method"; do
  if ! grep -q "$attr" "$LOG"; then
    echo "FAIL: expected attribute '$attr' in console output"
    ok=0
  fi
done

if ! grep -q "ERROR" "$LOG"; then
  echo "FAIL: no ERROR status recorded (over-limit payment should set it)"
  ok=0
fi

if ! grep -q "amount above limit" "$LOG"; then
  echo "FAIL: exception message 'amount above limit' not recorded"
  ok=0
fi

if [ "$ok" -eq 1 ]; then
  echo "OK: otel-04-02 — domain spans added correctly"
  exit 0
else
  echo "---- log (first 120 lines) ----"
  head -120 "$LOG"
  exit 1
fi
