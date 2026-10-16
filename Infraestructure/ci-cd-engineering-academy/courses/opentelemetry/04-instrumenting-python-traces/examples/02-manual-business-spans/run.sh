#!/usr/bin/env bash
# Smoke test for example 02: nested business spans with ConsoleSpanExporter.
#
# Note: we deliberately do NOT enable `set -o pipefail` because `grep -q` with
# pipes may close early (SIGPIPE / exit 141); pipefail would spuriously fail.

set -eu

cd "$(dirname "$0")"

if ! python3 -c "import opentelemetry.sdk" 2>/dev/null; then
  echo "SKIP: missing opentelemetry-sdk"
  exit 0
fi

OUT=$(mktemp /tmp/otel04-ex02.XXXXXX)
trap 'rm -f "$OUT"' EXIT

python3 app.py > "$OUT" 2>&1 || {
  echo "FAIL: app.py exited non-zero"
  cat "$OUT"
  exit 1
}

ok=1
for name in "checkout.process" "inventory.reserve" "payment.charge"; do
  if ! grep -q "\"name\": \"$name\"" "$OUT" && ! grep -q "\"name\":\"$name\"" "$OUT"; then
    echo "FAIL: span '$name' not found in output"
    ok=0
  fi
done

if ! grep -q "fraud.check.passed" "$OUT"; then
  echo "FAIL: event 'fraud.check.passed' not found"
  ok=0
fi

if ! grep -q "checkout.cart_id" "$OUT"; then
  echo "FAIL: attribute 'checkout.cart_id' not found"
  ok=0
fi

if [ "$ok" -eq 1 ]; then
  echo "OK: example 02 — business spans with attributes and events"
  exit 0
else
  echo "---- output (first 80 lines) ----"
  head -80 "$OUT"
  exit 1
fi
