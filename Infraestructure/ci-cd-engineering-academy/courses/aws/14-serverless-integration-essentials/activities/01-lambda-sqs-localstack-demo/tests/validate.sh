#!/usr/bin/env bash
# Structural + optional runtime validation for aws-14-01-lambda-sqs-localstack-demo.
#
# Always checks the handler.py structure (so the activity is still gradable
# without Docker). If LocalStack is reachable on localhost:4566 AND the demo
# resources exist (queue 'orders', function 'orders-worker'), also verifies
# them. If LocalStack is not available, prints a clear SKIP and continues.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/aws-14-lambda-sqs}"
HANDLER="$BASE/handler.py"
fail=0

echo "== Validation for $BASE =="

# ---- Part A: directory + handler structural checks (always run) ----
if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Create it and copy handler.py (see README)."
  exit 1
fi

if [ ! -f "$HANDLER" ]; then
  echo "FAIL: $HANDLER does not exist. Copy starter/handler.py into $BASE."
  exit 1
fi

if grep -qE '^def[[:space:]]+lambda_handler[[:space:]]*\(' "$HANDLER"; then
  echo "  OK   handler.py defines lambda_handler"
else
  echo "  FAIL handler.py does not define lambda_handler(event, context)"
  fail=$((fail+1))
fi

# No print() for operational data — use logging.
if grep -qE '^\s*print\(' "$HANDLER"; then
  echo "  FAIL handler.py uses print(); use logging instead"
  fail=$((fail+1))
else
  echo "  OK   handler.py does not use print()"
fi

# Must import logging.
if grep -qE '^import +logging' "$HANDLER"; then
  echo "  OK   handler.py imports logging"
else
  echo "  FAIL handler.py does not import logging"
  fail=$((fail+1))
fi

# Must use json for structured logs (json.dumps appears).
if grep -q 'json.dumps' "$HANDLER"; then
  echo "  OK   handler.py uses json.dumps (structured logging)"
else
  echo "  FAIL handler.py does not use json.dumps (no structured logging)"
  fail=$((fail+1))
fi

# Must reference an aws_request_id or build a correlation id.
if grep -qE 'aws_request_id|request_id' "$HANDLER"; then
  echo "  OK   handler.py uses a correlation id (aws_request_id / request_id)"
else
  echo "  FAIL handler.py does not use a correlation id"
  fail=$((fail+1))
fi

# Must perform some event validation (any InvalidEvent-ish exception or guard).
if grep -qiE 'raise .*(Invalid|ValueError)|if +not .*records' "$HANDLER"; then
  echo "  OK   handler.py validates the incoming event"
else
  echo "  FAIL handler.py does not appear to validate the event"
  fail=$((fail+1))
fi

# Byte-compile check: valid Python 3 syntax.
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import py_compile, sys; py_compile.compile('$HANDLER', doraise=True)" >/dev/null 2>&1; then
    echo "  OK   handler.py is syntactically valid Python 3"
  else
    echo "  FAIL handler.py has Python syntax errors"
    fail=$((fail+1))
  fi
else
  echo "  SKIP python3 not available; cannot syntax-check handler.py"
fi

echo

# ---- Part B: optional LocalStack runtime checks ----
LS_URL="http://localhost:4566"

ls_available=0
if command -v curl >/dev/null 2>&1; then
  if curl -fs --max-time 2 "$LS_URL/_localstack/health" >/dev/null 2>&1; then
    ls_available=1
  fi
fi

if [ "$ls_available" -eq 0 ]; then
  echo "SKIP: localstack not available at $LS_URL (demo verification skipped;"
  echo "      handler.py structural checks above are enough to pass this activity)"
else
  echo "== LocalStack reachable, verifying demo resources =="

  export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
  export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

  if ! command -v aws >/dev/null 2>&1; then
    echo "  SKIP aws CLI not installed; cannot verify LocalStack resources"
  else
    if aws --endpoint-url="$LS_URL" sqs get-queue-url --queue-name orders >/dev/null 2>&1; then
      echo "  OK   SQS queue 'orders' exists in LocalStack"
    else
      echo "  WARN SQS queue 'orders' not found (did you run §5.4 of README?)"
    fi

    if aws --endpoint-url="$LS_URL" lambda get-function --function-name orders-worker >/dev/null 2>&1; then
      echo "  OK   Lambda 'orders-worker' exists in LocalStack"
    else
      echo "  WARN Lambda 'orders-worker' not found (did you run §5.6 of README?)"
    fi
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  exit 1
fi
echo "OK: handler estructuralmente valido. Compara con solution/REFERENCE.md."
exit 0
