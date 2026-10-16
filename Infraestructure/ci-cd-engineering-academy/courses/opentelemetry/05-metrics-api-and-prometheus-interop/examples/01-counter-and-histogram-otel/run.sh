#!/usr/bin/env bash
# Runs example 01 and verifies the console exporter printed the expected metrics.
# NOTE: no `set -o pipefail` because `grep -q` on captured output may SIGPIPE.
set -eu

cd "$(dirname "$0")"

if ! python3 -c "from opentelemetry.sdk.metrics import MeterProvider" 2>/dev/null; then
  echo "SKIP: opentelemetry-sdk not installed"
  exit 0
fi

OUT=$(mktemp /tmp/otel05-ex01.XXXXXX)
trap 'rm -f "$OUT"' EXIT

python3 app.py > "$OUT" 2>&1 || { echo "FAIL: app.py errored"; cat "$OUT"; exit 1; }

ok=1
grep -q 'http.server.requests' "$OUT" || { echo "FAIL: counter missing"; ok=0; }
grep -q 'http.server.duration' "$OUT" || { echo "FAIL: histogram missing"; ok=0; }
grep -q 'myapp.queue.depth' "$OUT"    || { echo "FAIL: observable gauge missing"; ok=0; }

if [ "$ok" -eq 1 ]; then
  echo "OK: example 01 emitted counter + histogram + observable gauge"
else
  echo "---- captured output (last 60 lines) ----"
  tail -60 "$OUT"
  exit 1
fi
