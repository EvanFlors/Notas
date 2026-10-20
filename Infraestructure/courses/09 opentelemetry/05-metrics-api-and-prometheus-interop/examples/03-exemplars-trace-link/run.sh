#!/usr/bin/env bash
# NOTE: no `set -o pipefail` on purpose.
set -eu

cd "$(dirname "$0")"

if ! python3 -c "from opentelemetry.sdk.metrics import MeterProvider; from opentelemetry.sdk.trace import TracerProvider" 2>/dev/null; then
  echo "SKIP: opentelemetry-sdk not installed"
  exit 0
fi

OUT=$(mktemp /tmp/otel05-ex03.XXXXXX)
trap 'rm -f "$OUT"' EXIT

python3 app.py > "$OUT" 2>&1 || { echo "FAIL: app errored"; cat "$OUT"; exit 1; }

ok=1
grep -q 'work.duration' "$OUT" || { echo "FAIL: histogram missing"; ok=0; }
grep -q '"trace_id"' "$OUT"    || { echo "FAIL: no trace_id in exemplars"; ok=0; }
grep -q '"span_id"' "$OUT"     || { echo "FAIL: no span_id in exemplars"; ok=0; }

if [ "$ok" -eq 1 ]; then
  echo "OK: example 03 emitted histogram with exemplars (trace_id + span_id)"
else
  echo "---- last 80 lines ----"
  tail -80 "$OUT"
  exit 1
fi
