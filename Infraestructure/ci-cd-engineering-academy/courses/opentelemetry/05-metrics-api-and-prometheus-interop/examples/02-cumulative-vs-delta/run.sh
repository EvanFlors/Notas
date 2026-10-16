#!/usr/bin/env bash
# NOTE: no `set -o pipefail` on purpose (grep -q may SIGPIPE early).
set -eu

cd "$(dirname "$0")"

if ! python3 -c "from opentelemetry.sdk.metrics import MeterProvider" 2>/dev/null; then
  echo "SKIP: opentelemetry-sdk not installed"
  exit 0
fi

OUT=$(mktemp /tmp/otel05-ex02.XXXXXX)
trap 'rm -f "$OUT"' EXIT

python3 app.py > "$OUT" 2>&1 || { echo "FAIL: app.py errored"; cat "$OUT"; exit 1; }

ok=1
# aggregation_temporality is serialised as int in JSON: 2=CUMULATIVE, 1=DELTA.
grep -q '"aggregation_temporality": 2' "$OUT" || ok=0
grep -q '"aggregation_temporality": 1' "$OUT" || ok=0
grep -q 'demo.events' "$OUT"                  || ok=0

if [ "$ok" -eq 1 ]; then
  echo "OK: example 02 exported both CUMULATIVE and DELTA for demo.events"
else
  echo "FAIL: temporality strings not found in output"
  echo "---- last 50 lines ----"
  tail -50 "$OUT"
  exit 1
fi
