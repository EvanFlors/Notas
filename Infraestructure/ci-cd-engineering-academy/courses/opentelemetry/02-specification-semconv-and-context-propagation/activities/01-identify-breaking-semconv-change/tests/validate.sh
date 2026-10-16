#!/usr/bin/env bash
# Validate the student's answer.md for otel-02-01.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# use `grep -q` which exits early (closing the pipe) and can cause the upstream
# producer to receive SIGPIPE (exit 141). pipefail would mark those as failures.

ANSWER="${ANSWER:-/tmp/otel-02-01-samples/answer.md}"
passed=0
failed=0
report=""

if [ ! -f "$ANSWER" ]; then
  echo "FAIL: $ANSWER not found. Run starter/build-samples.sh and fill in your answer." >&2
  exit 1
fi

# A) must mention at least these deprecated attribute names.
for attr in "http.method" "http.status_code" "http.url" "http.target" "http.host"; do
  if grep -q "$attr" "$ANSWER"; then
    report+="OK mention of deprecated '$attr'\n"
    passed=$((passed+1))
  else
    report+="FAIL missing mention of deprecated '$attr'\n"
    failed=$((failed+1))
  fi
done

# B) must mention at least these current attribute names.
for attr in "http.request.method" "http.response.status_code" "url.full" "url.path" "server.address"; do
  if grep -q "$attr" "$ANSWER"; then
    report+="OK mention of current '$attr'\n"
    passed=$((passed+1))
  else
    report+="FAIL missing mention of current '$attr'\n"
    failed=$((failed+1))
  fi
done

# C) must classify services a/b/c.
for svc in "service-a" "service-b" "service-c"; do
  if grep -q "$svc" "$ANSWER"; then
    report+="OK classification of '$svc'\n"
    passed=$((passed+1))
  else
    report+="FAIL missing classification of '$svc'\n"
    failed=$((failed+1))
  fi
done

# D) migration plan: must mention dual-emit.
if grep -qiE "dual[- ]?emit" "$ANSWER"; then
  report+="OK mentions dual-emit strategy\n"
  passed=$((passed+1))
else
  report+="FAIL does not mention dual-emit\n"
  failed=$((failed+1))
fi

# D2) must mention cutoff / cutover / corte.
if grep -qiE "cutoff|cutover|corte|apagar" "$ANSWER"; then
  report+="OK mentions a cutoff criterion\n"
  passed=$((passed+1))
else
  report+="FAIL does not mention a cutoff criterion\n"
  failed=$((failed+1))
fi

total=$((passed+failed))

echo "== otel-02-01 answer validation =="
printf "%b" "$report"
echo
echo "RESULT: $passed/$total checks passed."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
echo "RESULT: OK"
exit 0
