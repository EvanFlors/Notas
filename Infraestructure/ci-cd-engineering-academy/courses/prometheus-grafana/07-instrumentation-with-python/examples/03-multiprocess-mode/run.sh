#!/usr/bin/env bash
# Smoke test for multiprocess mode via gunicorn.
set -eu

cd "$(dirname "$0")"

if ! python3 -c "import fastapi, uvicorn, gunicorn, prometheus_client" 2>/dev/null; then
  echo "SKIP: missing python deps (fastapi, uvicorn, gunicorn, prometheus_client)"
  exit 0
fi

PORT="${PORT:-8767}"
MPDIR="${MPDIR:-/tmp/obs07-mp-$$}"
rm -rf "$MPDIR"
mkdir -p "$MPDIR"
export PROMETHEUS_MULTIPROC_DIR="$MPDIR"

LOG=$(mktemp /tmp/obs07-ex03.XXXXXX)

python3 -m gunicorn \
  --workers 2 \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind "127.0.0.1:${PORT}" \
  --config gunicorn.conf.py \
  --log-level warning \
  app:app > "$LOG" 2>&1 &
PID=$!

cleanup() {
  kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
  rm -rf "$MPDIR"
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
  echo "FAIL: gunicorn did not come up"
  echo "---- log ----"
  cat "$LOG"
  exit 1
fi

for _ in $(seq 1 10); do
  curl -fs "http://127.0.0.1:${PORT}/hit" > /dev/null
done

METRICS=$(curl -fs "http://127.0.0.1:${PORT}/metrics")

ok=1
echo "$METRICS" | grep -q '^mp_requests_total{endpoint="/hit"}' \
  || { echo "FAIL: mp_requests_total missing"; ok=0; }
echo "$METRICS" | grep -qE '^mp_worker_pid_info( |\{)' \
  || { echo "FAIL: mp_worker_pid_info missing"; ok=0; }

# Count should be >= 10 across workers.
total=$(echo "$METRICS" | awk '/^mp_requests_total\{endpoint="\/hit"\}/ {print $2}')
if [ -z "$total" ] || awk -v v="$total" 'BEGIN{exit !(v+0 >= 10)}'; then
  :
else
  echo "FAIL: expected mp_requests_total >= 10, got '$total'"
  ok=0
fi

if [ "$ok" -eq 1 ]; then
  echo "OK: example 03 multiprocess mode works (total hits: $total)"
  exit 0
else
  echo "---- metrics (head) ----"
  echo "$METRICS" | head -30
  exit 1
fi
