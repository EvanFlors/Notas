#!/usr/bin/env bash
# Demo: SSM Parameter Store SecureString encrypted with a customer-managed CMK.
# Runs against LocalStack. SKIPs cleanly if LocalStack / aws CLI are missing.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some pipes
# (e.g. `curl ... | jq`) may exit 141 (SIGPIPE) on early close and spuriously
# fail the demo. We keep `set -eu` for safety on undefined vars and errors.

set -eu

ENDPOINT="${AWS_ENDPOINT_URL:-http://localhost:4566}"
export AWS_ENDPOINT_URL="$ENDPOINT"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"

PARAM_NAME="/aws-09/example/db/password"
FAKE_VALUE="fake-password-NOT-REAL"
CMK_ID=""

cleanup() {
  echo "-- cleanup --"
  aws ssm delete-parameter --name "$PARAM_NAME" >/dev/null 2>&1 || true
  if [ -n "$CMK_ID" ]; then
    aws kms schedule-key-deletion --key-id "$CMK_ID" --pending-window-in-days 7 \
      >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "== Check LocalStack health =="
if ! command -v aws >/dev/null 2>&1; then
  echo "SKIP: 'aws' CLI not installed."
  exit 0
fi
if ! curl -fs "$ENDPOINT/_localstack/health" >/dev/null 2>&1; then
  echo "SKIP: LocalStack not reachable at $ENDPOINT."
  exit 0
fi

echo "== 1. Create customer-managed CMK =="
CMK_ID=$(aws kms create-key \
  --description "aws-09-ex03-cmk" \
  --query 'KeyMetadata.KeyId' --output text)
echo "   KeyId=$CMK_ID"

echo "== 2. Put SecureString parameter =="
aws ssm put-parameter \
  --name "$PARAM_NAME" \
  --value "$FAKE_VALUE" \
  --type SecureString \
  --key-id "$CMK_ID" \
  --overwrite >/dev/null
echo "   wrote $PARAM_NAME (type=SecureString, keyId=$CMK_ID)"

echo "== 3. Read WITHOUT decryption =="
RAW=$(aws ssm get-parameter --name "$PARAM_NAME" \
  --query 'Parameter.Value' --output text)
echo "   raw.value=$RAW"

echo "== 4. Read WITH decryption =="
DEC=$(aws ssm get-parameter --name "$PARAM_NAME" --with-decryption \
  --query 'Parameter.Value' --output text)
echo "   decrypted.value=$DEC"

if [ "$DEC" = "$FAKE_VALUE" ]; then
  echo "OK: decrypted value matches the written fake value."
else
  echo "WARN: decrypted value differs. (LocalStack may stub SecureString partially.)"
fi

echo "== done =="
