#!/usr/bin/env bash
# Validate otel-07-01: start service_b, run service_a once, compare trace_ids.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# use `grep -q` on piped streams which can SIGPIPE (exit 141); pipefail would
# spuriously fail those pipelines.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"
APP_DIR="${APP_DIR:-$ACT_DIR/starter}"

if ! python3 -c "import opentelemetry.sdk.trace" 2>/dev/null; then
  echo "SKIP: opentelemetry-sdk not installed (pip install opentelemetry-sdk)"
  exit 0
fi

PORT="${PORT:-8810}"
SRV_LOG="$(mktemp /tmp/otel07-01-srv.XXXXXX)"
CLI_LOG="$(mktemp /tmp/otel07-01-cli.XXXXXX)"
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

# Wait for the server to accept connections (bash /dev/tcp probe).
up=0
for _ in $(seq 1 50); do
  if (echo > "/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then up=1; break; fi
  sleep 0.2
done

if [ "$up" = "0" ]; then
  echo "FAIL: service_b did not come up on port $PORT"
  echo "---- server log ----"; cat "$SRV_LOG"
  exit 1
fi

B_URL="http://127.0.0.1:${PORT}/" python3 service_a.py > "$CLI_LOG" 2>&1 || {
  echo "FAIL: service_a crashed"
  echo "---- client log ----"; cat "$CLI_LOG"
  echo "---- server log ----"; cat "$SRV_LOG"
  exit 1
}

# Give the SimpleSpanProcessor on the server a moment to flush its span to stdout.
sleep 0.3

tid_cli="$(grep -oE '"trace_id": "0x[0-9a-f]+"' "$CLI_LOG" | head -1 || true)"
tid_srv="$(grep -oE '"trace_id": "0x[0-9a-f]+"' "$SRV_LOG" | head -1 || true)"

echo "client trace_id: $tid_cli"
echo "server trace_id: $tid_srv"

if [ -z "$tid_cli" ] || [ -z "$tid_srv" ]; then
  echo "FAIL: missing trace_id in logs"
  echo "---- client ----"; cat "$CLI_LOG"
  echo "---- server ----"; cat "$SRV_LOG"
  exit 1
fi

if [ "$tid_cli" = "$tid_srv" ]; then
  # Extra: service B span should have a non-zero parent (meaning extract worked).
  if grep -q '"parent_id": "0x[0-9a-f]*[1-9a-f][0-9a-f]*"' "$SRV_LOG"; then
    echo "OK: trace_id matches end-to-end and B has a parent"
    exit 0
  fi
  echo "FAIL: trace_id matches but service_b span has no parent (extract failed?)"
  exit 1
fi

echo "FAIL: trace_id differs — did you call inject(headers) in service_a?"
exit 1
