#!/usr/bin/env bash
# Structural validation for aws-12-01-instrument-fastapi-with-adot.
# Checks:
#   - $BASE/config.yaml exists, parses as YAML, and declares the required
#     receivers / processors / exporters / pipelines.
#   - $BASE/NOTES.md exists with >=5 numbered bullets and mentions IRSA / Pod Identity.
#   - Optional smoke: if docker + a LocalStack image are available, create a
#     CloudWatch Logs log group via LocalStack. Skip (not fail) otherwise.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# pipe producers into `grep -q`, which can exit on SIGPIPE (141) when grep
# finds a match early. pipefail would mark these as spurious failures.
set -eu

BASE="${1:-/tmp/aws-12-adot}"
CFG="$BASE/config.yaml"
NOTES="$BASE/NOTES.md"
fail=0

echo "== Structural validation for $BASE =="

# ---------------------------------------------------------------- config.yaml
if [ ! -f "$CFG" ]; then
  echo "FAIL: $CFG does not exist. Student must produce it."
  exit 1
fi

# YAML parse check (requires python3 + PyYAML; fall back to a lax check otherwise).
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import yaml,sys; yaml.safe_load(open('$CFG'))" 2>/dev/null; then
    echo "  OK   config.yaml parses as YAML"
  else
    echo "  FAIL config.yaml is not valid YAML"
    fail=$((fail+1))
  fi
else
  echo "  SKIP python3 not available; skipping YAML parse check"
fi

check_grep() {
  # $1 = label, $2 = regex (ERE), $3 = file
  if grep -qE "$2" "$3"; then
    echo "  OK   $1"
  else
    echo "  FAIL $1 (missing /$2/)"
    fail=$((fail+1))
  fi
}

check_grep "receivers.otlp present"              '^[[:space:]]*otlp:'                     "$CFG"
check_grep "otlp.grpc endpoint on :4317"         'grpc:|endpoint:.*4317'                  "$CFG"
check_grep "otlp.http endpoint on :4318"         'http:|endpoint:.*4318'                  "$CFG"
check_grep "processor batch present"             '^[[:space:]]*batch:'                    "$CFG"
check_grep "processor memory_limiter present"    '^[[:space:]]*memory_limiter:'           "$CFG"
check_grep "exporter awsxray present"            '^[[:space:]]*awsxray:'                  "$CFG"
check_grep "exporter awsemf present"             '^[[:space:]]*awsemf:'                   "$CFG"
check_grep "exporter awscloudwatchlogs present"  '^[[:space:]]*awscloudwatchlogs:'        "$CFG"
check_grep "exporter prometheusremotewrite"      '^[[:space:]]*prometheusremotewrite:'    "$CFG"
check_grep "service.pipelines block present"     '^[[:space:]]*pipelines:'                "$CFG"
check_grep "pipeline traces wires awsxray"       'traces:.*|awsxray'                      "$CFG"
check_grep "pipeline metrics wires awsemf"       'awsemf'                                 "$CFG"
check_grep "pipeline metrics wires prom RW"      'prometheusremotewrite'                  "$CFG"
check_grep "pipeline logs wires awscloudwatchlogs" 'awscloudwatchlogs'                    "$CFG"

# Must NOT contain static credentials or a real-looking account id.
if grep -qE 'AKIA[0-9A-Z]{16}|aws_access_key_id|aws_secret_access_key' "$CFG"; then
  echo "  FAIL config.yaml appears to contain static AWS credentials"
  fail=$((fail+1))
else
  echo "  OK   config.yaml has no static AWS credentials"
fi

if grep -qE '\b[0-9]{12}\b' "$CFG"; then
  acct=$(grep -oE '\b[0-9]{12}\b' "$CFG" | head -n 1)
  # Allow the AWS-published example account id 123456789012; anything else fails.
  if [ "$acct" = "123456789012" ]; then
    echo "  OK   only AWS example account id (123456789012) found"
  else
    echo "  FAIL config.yaml contains a 12-digit id ($acct) that is not the AWS example"
    fail=$((fail+1))
  fi
else
  echo "  OK   config.yaml has no 12-digit account id"
fi

# -------------------------------------------------------------------- NOTES.md
if [ ! -f "$NOTES" ]; then
  echo "  FAIL $NOTES does not exist"
  fail=$((fail+1))
else
  bullets=0
  for n in 1 2 3 4 5; do
    if grep -Eq "^[[:space:]]*${n}\\." "$NOTES"; then
      bullets=$((bullets+1))
    fi
  done
  if [ "$bullets" -ge 5 ]; then
    echo "  OK   NOTES.md has at least 5 numbered bullets ($bullets found)"
  else
    echo "  FAIL NOTES.md has only $bullets numbered bullets (expected >=5)"
    fail=$((fail+1))
  fi

  if grep -qiE 'irsa|pod[- ]identity' "$NOTES"; then
    echo "  OK   NOTES.md mentions IRSA / Pod Identity"
  else
    echo "  FAIL NOTES.md does not mention IRSA nor Pod Identity"
    fail=$((fail+1))
  fi
fi

# ----------------------------------------------------- Optional LocalStack smoke
LS_NAME="localstack-aws12-validate"
cleanup_ls() {
  docker rm -f "$LS_NAME" >/dev/null 2>&1 || true
}

run_smoke=1
if ! command -v docker >/dev/null 2>&1; then
  echo "  SKIP docker not found; skipping LocalStack CloudWatch Logs smoke"
  run_smoke=0
fi
if [ "$run_smoke" -eq 1 ] && ! docker info >/dev/null 2>&1; then
  echo "  SKIP docker daemon not reachable; skipping LocalStack smoke"
  run_smoke=0
fi
if [ "$run_smoke" -eq 1 ] && ! command -v aws >/dev/null 2>&1; then
  echo "  SKIP aws CLI not found; skipping LocalStack smoke"
  run_smoke=0
fi

if [ "$run_smoke" -eq 1 ]; then
  echo "== LocalStack smoke (CloudWatch Logs create-log-group) =="
  trap cleanup_ls EXIT
  docker rm -f "$LS_NAME" >/dev/null 2>&1 || true
  if ! docker run -d --rm --name "$LS_NAME" -p 14566:4566 \
         -e SERVICES=logs localstack/localstack:3 >/dev/null 2>&1; then
    echo "  SKIP could not pull/start LocalStack image"
  else
    ready=0
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
      if curl -sf http://localhost:14566/_localstack/health >/dev/null 2>&1; then
        ready=1
        break
      fi
      sleep 1
    done
    if [ "$ready" -ne 1 ]; then
      echo "  SKIP LocalStack did not report ready in 15s"
    else
      if AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
           aws --endpoint-url http://localhost:14566 logs create-log-group \
           --log-group-name /aws/app/fastapi >/dev/null 2>&1; then
        echo "  OK   created log group /aws/app/fastapi in LocalStack"
      else
        echo "  FAIL could not create log group in LocalStack"
        fail=$((fail+1))
      fi
    fi
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Compare config.yaml and NOTES.md with solution/ to self-grade.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/ para autoevaluarte."
exit 0
