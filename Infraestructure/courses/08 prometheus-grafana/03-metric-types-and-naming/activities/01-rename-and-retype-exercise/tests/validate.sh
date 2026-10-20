#!/usr/bin/env bash
# Validate obs-03-01: /tmp/obs03-01/metrics_fixed.txt applies the naming
# and typing conventions.
#
# Note: NOT using `set -o pipefail` because many checks use `grep -q` on piped
# input and SIGPIPE would spuriously mark passing checks as failures.
set -eu

TARGET="${TARGET:-/tmp/obs03-01/metrics_fixed.txt}"
passed=0
failed=0
report=""

check() {
  local name="$1"
  local ok="$2"
  local why="$3"
  if [ "$ok" -eq 1 ]; then
    report+="OK   — ${name}\n"; passed=$((passed + 1))
  else
    report+="FAIL — ${name}: ${why}\n"; failed=$((failed + 1))
  fi
}

if [ ! -f "$TARGET" ]; then
  echo "FAIL: no existe $TARGET. Crea /tmp/obs03-01 y edita el fichero."
  exit 1
fi

# 1) Counter correct: http_requests_total exists with # TYPE counter
has_counter_type=0
if grep -Eq '^# TYPE http_requests_total counter$' "$TARGET" \
   && grep -Eq '^http_requests_total\{' "$TARGET"; then
  has_counter_type=1
fi
check "http_requests_total declared as counter" "$has_counter_type" \
      "falta '# TYPE http_requests_total counter' o la métrica no aparece"

# 2) No camelCase
no_camel=1
if grep -Eq '^[A-Za-z_][A-Za-z_0-9]*[a-z][A-Z]' "$TARGET"; then
  no_camel=0
fi
check "no camelCase anywhere" "$no_camel" \
      "se detectó camelCase (p.ej. httpRequests). Usa snake_case."

# 3) Duration in seconds as histogram with _bucket
has_hist=0
if grep -Eq '^# TYPE http_request_duration_seconds histogram$' "$TARGET" \
   && grep -Eq '^http_request_duration_seconds_bucket\{' "$TARGET" \
   && grep -Eq '^http_request_duration_seconds_count' "$TARGET" \
   && grep -Eq '^http_request_duration_seconds_sum' "$TARGET"; then
  has_hist=1
fi
check "http_request_duration_seconds is a histogram with _bucket/_count/_sum" "$has_hist" \
      "faltan artefactos del histogram o la unidad no es _seconds"

# 4) No forbidden unit suffixes (_ms, _mb, _kb, _gb, _percent)
no_bad_units=1
if grep -Eq '(_ms|_mb|_kb|_gb|_percent)([{ ]|$)' "$TARGET"; then
  no_bad_units=0
fi
check "no non-canonical units (_ms/_mb/_kb/_gb/_percent)" "$no_bad_units" \
      "usa _seconds, _bytes y _ratio en vez de _ms/_mb/_kb/_gb/_percent"

# 5) Memory metric uses _bytes
has_bytes=0
if grep -Eq '^process_memory_used_bytes' "$TARGET"; then
  has_bytes=1
fi
check "process_memory_used_bytes exists" "$has_bytes" \
      "renombra memory_used_mb → process_memory_used_bytes"

# 6) CPU uses _ratio (0..1)
has_ratio=0
if grep -Eq '^# TYPE process_cpu_usage_ratio gauge$' "$TARGET" \
   && grep -Eq '^process_cpu_usage_ratio ' "$TARGET"; then
  has_ratio=1
fi
check "process_cpu_usage_ratio is a gauge" "$has_ratio" \
      "renombra cpu_usage_percent → process_cpu_usage_ratio y usa 0..1"

# 7) Gauges do not carry _total
no_gauge_total=1
# Any _total line whose TYPE comment above says gauge is a bug.
# Simpler heuristic: 'active_connections' and 'queue_size' must not end in _total.
if grep -Eq '^active_connections_total' "$TARGET"; then no_gauge_total=0; fi
if grep -Eq '^queue_size_total' "$TARGET"; then no_gauge_total=0; fi
check "gauges don't carry _total (active_connections, queue_size)" "$no_gauge_total" \
      "quita el sufijo _total de los gauges"

# 8) Summary converted away (no 'summary' TYPE for request_duration)
no_summary=1
if grep -Eq '^# TYPE .*_summary? summary$' "$TARGET"; then
  no_summary=0
fi
# Also forbid the original name 'request_duration_summary' entirely.
if grep -Eq '^request_duration_summary' "$TARGET"; then
  no_summary=0
fi
check "summary replaced by histogram (no 'summary' type remains)" "$no_summary" \
      "elimina el summary y usa un histogram agregable"

echo "== obs-03-01 validation =="
printf "%b" "$report"
echo
echo "RESULT: $passed/8 checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
