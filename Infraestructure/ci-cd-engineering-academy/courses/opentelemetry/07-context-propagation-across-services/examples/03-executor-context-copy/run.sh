#!/usr/bin/env bash
# Prove: broken.py yields 2 trace_ids, fixed.py yields 1.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"

if ! python3 -c "import opentelemetry.sdk.trace" 2>/dev/null; then
  echo "SKIP: install opentelemetry-sdk first"
  exit 0
fi

BR_LOG="$(mktemp /tmp/otel07-ex03-br.XXXXXX)"
FX_LOG="$(mktemp /tmp/otel07-ex03-fx.XXXXXX)"
trap 'rm -f "$BR_LOG" "$FX_LOG"' EXIT

cd "$HERE"
python3 broken.py > "$BR_LOG" 2>&1
python3 fixed.py  > "$FX_LOG" 2>&1

br_uniq="$(grep -oE '"trace_id": "0x[0-9a-f]+"' "$BR_LOG" | sort -u | wc -l | tr -d ' ')"
fx_uniq="$(grep -oE '"trace_id": "0x[0-9a-f]+"' "$FX_LOG" | sort -u | wc -l | tr -d ' ')"

echo "broken distinct trace_ids: $br_uniq (expected 2)"
echo "fixed  distinct trace_ids: $fx_uniq (expected 1)"

if [ "$br_uniq" = "2" ] && [ "$fx_uniq" = "1" ]; then
  echo "OK: executor context fix demonstrated"
  exit 0
fi
echo "FAIL: expected 2/1 distinct trace_ids"
echo "---- broken ----"; cat "$BR_LOG"
echo "---- fixed ----";  cat "$FX_LOG"
exit 1
