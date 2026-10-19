#!/usr/bin/env bash
# Setup: create CMK + fake Secrets Manager secret + fake SSM SecureString,
# all against LocalStack. SKIPs cleanly if LocalStack is not reachable.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some pipes
# (e.g. `curl ... | jq`, `aws ... | grep`) may exit 141 (SIGPIPE) and
# produce spurious failures. We keep `set -eu`.

set -eu

SCRATCH="${1:-/tmp/aws-09-store-fetch}"
mkdir -p "$SCRATCH"

ENDPOINT="${AWS_ENDPOINT_URL:-http://localhost:4566}"
export AWS_ENDPOINT_URL="$ENDPOINT"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"

KEY_POLICY="$SCRATCH/key-policy.json"
SECRET_NAME="fake/checkout/db"
PARAM_NAME="/aws-09/fake/checkout/db/endpoint"
# Fake payloads. NEVER use real secrets here.
FAKE_SECRET_JSON='{"username": "fake_app", "password": "fake-pw-NOT-REAL"}'
FAKE_PARAM_VALUE="fake.endpoint.localstack:5432"

write_skip() {
  local reason="$1"
  cat >"$SCRATCH/cmk.json" <<EOF
{"status":"SKIP","reason":"$reason"}
EOF
  cat >"$SCRATCH/secret.json" <<EOF
{"status":"SKIP","reason":"$reason","secret_name":"$SECRET_NAME"}
EOF
  cat >"$SCRATCH/param.json" <<EOF
{"status":"SKIP","reason":"$reason","param_name":"$PARAM_NAME"}
EOF
}

echo "== Preflight =="

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: 'jq' is required."
  exit 2
fi
if [ ! -f "$KEY_POLICY" ]; then
  echo "FAIL: $KEY_POLICY not found. Copy key-policy.template.json first."
  exit 2
fi
if ! jq empty "$KEY_POLICY" >/dev/null 2>&1; then
  echo "FAIL: $KEY_POLICY is not valid JSON."
  exit 2
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "SKIP: 'aws' CLI not installed. Writing SKIP artifacts."
  write_skip "aws-cli-missing"
  exit 0
fi
if ! curl -fs "$ENDPOINT/_localstack/health" >/dev/null 2>&1; then
  echo "SKIP: LocalStack not reachable at $ENDPOINT. Writing SKIP artifacts."
  write_skip "localstack-unreachable"
  exit 0
fi

echo "== 1. Create CMK =="
CMK_ID=$(aws kms create-key \
  --description "aws-09-01-store-fetch-cmk" \
  --policy "$(cat "$KEY_POLICY")" \
  --query 'KeyMetadata.KeyId' --output text)
echo "   KeyId=$CMK_ID"
cat >"$SCRATCH/cmk.json" <<EOF
{"status":"OK","key_id":"$CMK_ID","mode":"online"}
EOF

echo "== 2. Create Secrets Manager secret (fake) =="
aws secretsmanager create-secret \
  --name "$SECRET_NAME" \
  --kms-key-id "$CMK_ID" \
  --secret-string "$FAKE_SECRET_JSON" >/dev/null 2>&1 \
  || aws secretsmanager put-secret-value \
       --secret-id "$SECRET_NAME" \
       --secret-string "$FAKE_SECRET_JSON" >/dev/null
echo "   wrote $SECRET_NAME"
cat >"$SCRATCH/secret.json" <<EOF
{"status":"OK","secret_name":"$SECRET_NAME","mode":"online","note":"fake-value-labeled"}
EOF

echo "== 3. Create SSM SecureString parameter (fake) =="
aws ssm put-parameter \
  --name "$PARAM_NAME" \
  --value "$FAKE_PARAM_VALUE" \
  --type SecureString \
  --key-id "$CMK_ID" \
  --overwrite >/dev/null
echo "   wrote $PARAM_NAME"
cat >"$SCRATCH/param.json" <<EOF
{"status":"OK","param_name":"$PARAM_NAME","mode":"online","note":"fake-value-labeled"}
EOF

echo "== done. Scratch: $SCRATCH =="
