#!/usr/bin/env bash
# Validate otel-07-02: start service_b, run service_a, verify trace continuity.
#
# Note: no `set -o pipefail` — grep -q on piped streams can SIGPIPE (exit 141)
# and pipefail would spuriously mark those checks as failures.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"
APP_DIR="${APP_DIR:-$ACT_DIR/starter}"

if ! python3 -c "import opentelemetry.sdk.trace" 2>/dev/null; then
  echo "SKIP: opentelemetry-sdk not installed (pip install opentelemetry-sdk)"
  exit 0
fi

PORT="${PORT:-8820}"
SRV_LOG="$(mktemp /tmp/otel07-02-srv.XXXXXX)"
CLI_LOG="$(mktemp /tmp/otel07-02-cli.XXXXXX)"
PID=""

cleanup() {
  [ -n "$PID" ] && kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
  rm -f "$SRV_LOG" "$CLI_LOG"
}
trap cleanup EXIT

cd "$APP_DIR"
PORT="$PORT" python3 service_b.py > "$SRV_LOG" 2>&1 &
PID=$!

up=0
for _ in $(seq 1 50); do
  if (echo > "/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then up=1; break; fi
  sleep 0.2
done
if [ "$up" = "0" ]; then
  echo "FAIL: service_b did not come up on port $PORT"
  cat "$SRV_LOG"; exit 1
fi

B_URL="http://127.0.0.1:${PORT}/" python3 service_a.py > "$CLI_LOG" 2>&1 || {
  echo "FAIL: service_a crashed"
  cat "$CLI_LOG"
  exit 1
}

sleep 0.3

tid_cli="$(grep -oE '"trace_id": "0x[0-9a-f]+"' "$CLI_LOG" | head -1 || true)"
tid_srv="$(grep -oE '"trace_id": "0x[0-9a-f]+"' "$SRV_LOG" | head -1 || true)"

echo "client trace_id: $tid_cli"
echo "server trace_id: $tid_srv"

if [ -z "$tid_cli" ] || [ -z "$tid_srv" ]; then
  echo "FAIL: no spans emitted"
  echo "---- cli ----"; cat "$CLI_LOG"
  echo "---- srv ----"; cat "$SRV_LOG"
  exit 1
fi

if [ "$tid_cli" != "$tid_srv" ]; then
  echo "FAIL: trace_id differs — context not propagated across the hop"
  echo "Hints:"
  echo "  * Does service_a actually inject while a span is current?"
  echo "  * Does service_b hand the propagator a carrier whose keys match what the propagator looks for?"
  exit 1
fi

# B's span must have a non-zero parent_id (extract worked AND there was a parent to extract).
if ! grep -q '"parent_id": "0x[0-9a-f]*[1-9a-f][0-9a-f]*"' "$SRV_LOG"; then
  echo "FAIL: service_b span has no (non-zero) parent_id — extract didn't find a traceparent"
  echo "---- srv ----"; cat "$SRV_LOG"
  exit 1
fi

echo "OK: trace propagated end-to-end and service_b has a real parent span"
exit 0
