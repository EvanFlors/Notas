#!/usr/bin/env bash
# Serve examples/01 metrics.txt via python http.server and curl it.
# Deliberately NO `set -o pipefail` — grep -q with pipes would spuriously fail.
set -eu

PORT="${PORT:-8080}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PIDFILE="/tmp/obs03-ex01.pid"

cleanup() {
  if [ -f "$PIDFILE" ]; then
    local pid
    pid="$(cat "$PIDFILE" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
  fi
}
trap cleanup EXIT INT TERM

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 no está disponible — este ejemplo necesita stdlib http.server."
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "SKIP: curl no está disponible."
  exit 0
fi

cd "$HERE"
echo "== Serving $HERE on :$PORT =="
python3 -m http.server "$PORT" >/tmp/obs03-ex01.log 2>&1 &
echo $! > "$PIDFILE"

# Wait briefly for the server to accept connections.
tries=0
while [ "$tries" -lt 20 ]; do
  if curl -sf "http://127.0.0.1:${PORT}/metrics.txt" -o /dev/null; then
    break
  fi
  tries=$((tries + 1))
  sleep 0.1
done

echo "== GET /metrics.txt =="
curl -sf "http://127.0.0.1:${PORT}/metrics.txt" || {
  echo "FAIL: no se pudo leer /metrics.txt"
  exit 1
}

echo
echo "== Done =="
