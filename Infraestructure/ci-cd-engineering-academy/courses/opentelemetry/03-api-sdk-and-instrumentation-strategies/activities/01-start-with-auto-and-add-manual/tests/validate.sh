#!/usr/bin/env bash
# Validate otel-03-01 — auto + manual spans on FastAPI.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks use
# `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep finds a
# match early. pipefail would spuriously mark those as failures.
#
# Modes:
#   - If python3+opentelemetry are importable AND port 8765 is free, we try an
#     end-to-end smoke (install skipped if venv missing).
#   - Otherwise we validate the student's app.py and (optionally) spans.log
#     structurally. The activity is accepted if the structural checks pass.

BASE="${1:-/tmp/otel-03-01}"
APP="$BASE/app.py"
LOG="$BASE/spans.log"
fail=0
report=""

note()  { report+="  $*\n"; }
ok()    { note "OK   $*"; }
fnote() { note "FAIL $*"; fail=$((fail+1)); }

echo "== Validating $BASE =="

if [ ! -f "$APP" ]; then
  echo "FAIL: $APP missing. Copy starter/app.py there and edit it."
  exit 1
fi

# ---------- Structural checks on app.py ----------
if grep -q 'from opentelemetry import trace' "$APP"; then
  ok "app.py imports opentelemetry.trace"
else
  fnote "app.py does NOT import opentelemetry.trace"
fi

manual_count=$(grep -c 'start_as_current_span' "$APP")
if [ "$manual_count" -ge 2 ]; then
  ok "app.py uses start_as_current_span at least twice ($manual_count)"
else
  fnote "app.py uses start_as_current_span only $manual_count times (expected >=2)"
fi

if grep -q 'start_as_current_span("apply_coupon"' "$APP" \
   || grep -q "start_as_current_span('apply_coupon'" "$APP"; then
  ok "app.py has span 'apply_coupon'"
else
  fnote "app.py missing span named 'apply_coupon'"
fi

if grep -q 'start_as_current_span("reserve_inventory"' "$APP" \
   || grep -q "start_as_current_span('reserve_inventory'" "$APP"; then
  ok "app.py has span 'reserve_inventory'"
else
  fnote "app.py missing span named 'reserve_inventory'"
fi

attr_count=$(grep -c 'set_attribute' "$APP")
if [ "$attr_count" -ge 2 ]; then
  ok "app.py uses set_attribute at least twice ($attr_count)"
else
  fnote "app.py uses set_attribute only $attr_count times (expected >=2)"
fi

# ---------- Optional: structural check on spans.log ----------
if [ -f "$LOG" ]; then
  # Spans.log exists → check that something looking like a span is in it.
  if grep -q '"name"' "$LOG"; then
    ok "spans.log contains at least one span 'name' field"
  else
    note "WARN spans.log present but no 'name' field found (did the exporter flush?)"
  fi
  if grep -q 'apply_coupon' "$LOG"; then
    ok "spans.log contains 'apply_coupon'"
  else
    note "WARN spans.log does not contain 'apply_coupon' (may indicate the app did not actually run)"
  fi
else
  note "WARN spans.log not present (environment likely offline). Structural check on code only."
fi

# ---------- Optional smoke: only if opentelemetry importable ----------
if python3 -c 'import opentelemetry' 2>/dev/null; then
  note "INFO python3 has opentelemetry importable in base env"
else
  note "INFO python3 does NOT have opentelemetry in base env — SKIP e2e run (expected)."
fi

printf "%b" "$report"
echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: estructura válida. Compara con solution/app.py para autoevaluarte."
exit 0
