#!/usr/bin/env bash
# Smoke demo: producer publishes with injected context, consumer extracts, trace_id matches.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"

if ! python3 -c "import opentelemetry.trace, opentelemetry.sdk.trace" 2>/dev/null; then
  echo "SKIP: install opentelemetry-sdk first"
  exit 0
fi

QUEUE="$(mktemp /tmp/otel07-ex02-queue.XXXXXX.jsonl)"
PROD_LOG="$(mktemp /tmp/otel07-ex02-prod.XXXXXX)"
CONS_LOG="$(mktemp /tmp/otel07-ex02-cons.XXXXXX)"
trap 'rm -f "$QUEUE" "$PROD_LOG" "$CONS_LOG"' EXIT

cd "$HERE"
python3 producer.py "$QUEUE" > "$PROD_LOG" 2>&1
python3 consumer.py "$QUEUE" > "$CONS_LOG" 2>&1

tid_prod="$(grep -oE '"trace_id": "0x[0-9a-f]+"' "$PROD_LOG" | head -1 || true)"
tid_cons="$(grep -oE '"trace_id": "0x[0-9a-f]+"' "$CONS_LOG" | head -1 || true)"

echo "producer trace_id: $tid_prod"
echo "consumer trace_id: $tid_cons"

if [ -n "$tid_prod" ] && [ "$tid_prod" = "$tid_cons" ]; then
  echo "OK: trace survived the (fake) Kafka hop via headers"
  exit 0
fi
echo "FAIL: trace_id mismatch"
echo "---- producer ----"; cat "$PROD_LOG"
echo "---- consumer ----"; cat "$CONS_LOG"
exit 1
