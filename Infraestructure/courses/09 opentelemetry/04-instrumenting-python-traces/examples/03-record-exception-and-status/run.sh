#!/usr/bin/env bash
# Smoke test for example 03: record_exception + set_status.
#
# Note: we deliberately do NOT enable `set -o pipefail` to avoid spurious
# failures from grep -q closing pipes early (SIGPIPE).

set -eu

cd "$(dirname "$0")"

if ! python3 -c "import opentelemetry.sdk" 2>/dev/null; then
  echo "SKIP: missing opentelemetry-sdk"
  exit 0
fi

OUT=$(mktemp /tmp/otel04-ex03.XXXXXX)
trap 'rm -f "$OUT"' EXIT

python3 app.py > "$OUT" 2>&1 || {
  echo "FAIL: app.py exited non-zero"
  cat "$OUT"
  exit 1
}

ok=1
for name in "payment.charge.manual-handling" "payment.charge.auto-handling"; do
  if ! grep -q "$name" "$OUT"; then
    echo "FAIL: span '$name' not found"
    ok=0
  fi
done

if ! grep -q "ValueError" "$OUT"; then
  echo "FAIL: exception.type ValueError not recorded"
  ok=0
fi

if ! grep -q "card declined" "$OUT"; then
  echo "FAIL: exception.message 'card declined' not recorded"
  ok=0
fi

# Both spans must have ERROR status. Console exporter renders as "status_code": "ERROR".
err_count=$(grep -c "ERROR" "$OUT" || true)
if [ "$err_count" -lt 2 ]; then
  echo "FAIL: expected at least 2 ERROR occurrences (both spans), got $err_count"
  ok=0
fi

if [ "$ok" -eq 1 ]; then
  echo "OK: example 03 — exceptions recorded and status=ERROR"
  exit 0
else
  echo "---- output (first 100 lines) ----"
  head -100 "$OUT"
  exit 1
fi
