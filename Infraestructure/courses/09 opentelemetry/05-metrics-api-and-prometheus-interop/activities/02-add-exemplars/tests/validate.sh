#!/usr/bin/env bash
# Validate otel-05-02: run the student's app, check the histogram output has
# exemplars carrying trace_id/span_id (i.e. tracing was wired correctly).
#
# NOTE: we deliberately do NOT enable `set -o pipefail` because `grep -q` on a
# large captured output may SIGPIPE early; pipefail would spuriously fail that.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ACT_DIR="$(dirname "$HERE")"
APP_DIR="${APP_DIR:-$ACT_DIR/solution}"

if ! python3 -c "from opentelemetry.sdk.trace import TracerProvider; from opentelemetry.sdk.metrics import MeterProvider" 2>/dev/null; then
  echo "SKIP: opentelemetry-sdk not installed"; exit 0
fi

OUT=$(mktemp /tmp/otel05-02.XXXXXX)
trap 'rm -f "$OUT"' EXIT

cd "$APP_DIR"
python3 app.py > "$OUT" 2>&1 || { echo "FAIL: app errored"; cat "$OUT"; exit 1; }

ok=1
grep -q 'work.duration' "$OUT" || { echo "FAIL: histogram missing"; ok=0; }

# Exemplars block appears per data point; detect at least one non-empty one.
# A non-empty exemplar in the console exporter shows "trace_id" and "span_id"
# keys with hex strings. An empty exemplars list prints "exemplars": [].
if ! python3 - <<PY
import json, re, sys
out = open("$OUT").read()
# Split out JSON blocks (console exporter prints each export as one JSON object).
blocks = re.findall(r"\{[\s\S]*?\n\}", out)
found = False
for b in blocks:
    try:
        obj = json.loads(b)
    except Exception:
        continue
    for rm in obj.get("resource_metrics", []):
        for sm in rm.get("scope_metrics", []):
            for m in sm.get("metrics", []):
                if m.get("name") != "work.duration":
                    continue
                for dp in m.get("data", {}).get("data_points", []):
                    for ex in dp.get("exemplars", []) or []:
                        if ex.get("trace_id") and ex.get("span_id"):
                            found = True
sys.exit(0 if found else 1)
PY
then
  echo "FAIL: no exemplar with trace_id+span_id found on work.duration"
  echo "---- output head ----"; head -120 "$OUT"
  ok=0
fi

if [ "$ok" -eq 1 ]; then
  echo "OK: otel-05-02 — histogram carries exemplars linked to trace"
  exit 0
else
  exit 1
fi
