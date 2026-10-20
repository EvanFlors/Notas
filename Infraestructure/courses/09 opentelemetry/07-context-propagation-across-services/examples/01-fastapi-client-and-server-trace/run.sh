#!/usr/bin/env bash
# Smoke demo: start Service B, run client A once, verify same trace_id in both logs.
# Skips gracefully if deps are missing.
#
# No `set -o pipefail` on purpose (grep -q on piped streams can SIGPIPE).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-8801}"

if ! python3 -c "import fastapi, uvicorn, httpx" 2>/dev/null; then
  echo "SKIP: install fastapi uvicorn httpx first"
  exit 0
fi
if ! python3 -c "import opentelemetry.instrumentation.fastapi, opentelemetry.instrumentation.httpx" 2>/dev/null; then
  echo "SKIP: install opentelemetry-instrumentation-fastapi + opentelemetry-instrumentation-httpx"
  exit 0
fi

SRV_LOG="$(mktemp /tmp/otel07-ex01-srv.XXXXXX)"
CLI_LOG="$(mktemp /tmp/otel07-ex01-cli.XXXXXX)"
cleanup() {
  [ -n "${PID:-}" ] && kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
  rm -f "$SRV_LOG" "$CLI_LOG"
}
trap cleanup EXIT

cd "$HERE"
python3 -m uvicorn server:app --port "$PORT" --log-level warning > "$SRV_LOG" 2>&1 &
PID=$!

for _ in $(seq 1 40); do
  curl -fs "http://127.0.0.1:${PORT}/compute?x=2" > /dev/null 2>&1 && break
  sleep 0.25
done

python3 client.py "http://127.0.0.1:${PORT}/compute?x=7" > "$CLI_LOG" 2>&1 || true

# Each ConsoleSpanExporter line contains the span dict. Extract any trace_id and compare.
tid_srv="$(grep -oE '"trace_id": "0x[0-9a-f]+"' "$SRV_LOG" | head -1 || true)"
tid_cli="$(grep -oE '"trace_id": "0x[0-9a-f]+"' "$CLI_LOG" | head -1 || true)"

echo "server trace_id: $tid_srv"
echo "client trace_id: $tid_cli"

if [ -n "$tid_srv" ] && [ "$tid_srv" = "$tid_cli" ]; then
  echo "OK: client and server share trace_id"
  exit 0
fi
echo "FAIL: trace_id differs (propagation broken)"
echo "---- server log tail ----"; tail -20 "$SRV_LOG"
echo "---- client log tail ----"; tail -20 "$CLI_LOG"
exit 1
