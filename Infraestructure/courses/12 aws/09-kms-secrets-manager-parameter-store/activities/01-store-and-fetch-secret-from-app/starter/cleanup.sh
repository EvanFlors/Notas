#!/usr/bin/env bash
# Cleanup for aws-09-01: remove the SSM param, the Secrets Manager secret,
# schedule CMK deletion, and remove the scratch dir.
#
# Note: we deliberately do NOT enable `set -o pipefail` because pipes like
# `aws ... | jq` may exit 141 (SIGPIPE) on early close. We keep `set -u`
# but intentionally omit `set -e` here because we want cleanup to continue
# even if an individual delete fails (e.g. resource already gone).

set -u

SCRATCH="${1:-/tmp/aws-09-store-fetch}"
ENDPOINT="${AWS_ENDPOINT_URL:-http://localhost:4566}"
export AWS_ENDPOINT_URL="$ENDPOINT"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"

SECRET_NAME="fake/checkout/db"
PARAM_NAME="/aws-09/fake/checkout/db/endpoint"

if command -v aws >/dev/null 2>&1 \
   && curl -fs "$ENDPOINT/_localstack/health" >/dev/null 2>&1; then
  echo "-- deleting SSM parameter --"
  aws ssm delete-parameter --name "$PARAM_NAME" 2>/dev/null || true

  echo "-- deleting Secrets Manager secret --"
  aws secretsmanager delete-secret --secret-id "$SECRET_NAME" \
    --force-delete-without-recovery 2>/dev/null || true

  if [ -f "$SCRATCH/cmk.json" ]; then
    CMK_ID=$(python3 -c "import json,sys; d=json.load(open('$SCRATCH/cmk.json')); print(d.get('key_id',''))" 2>/dev/null || echo "")
    if [ -n "$CMK_ID" ]; then
      echo "-- scheduling CMK $CMK_ID for deletion --"
      aws kms schedule-key-deletion --key-id "$CMK_ID" \
        --pending-window-in-days 7 >/dev/null 2>&1 || true
    fi
  fi
else
  echo "-- SKIP remote cleanup (LocalStack or aws CLI unavailable) --"
fi

echo "-- removing scratch $SCRATCH --"
rm -rf "$SCRATCH"
echo "done."
