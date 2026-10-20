#!/usr/bin/env bash
# Strict cleanup for capstone stage 07 — AWS (ECS Fargate + ALB + RDS + Secrets).
#
# Note: we deliberately do NOT enable `set -o pipefail` because grep-based
# checks can produce SIGPIPE (exit 141) when grep exits early. pipefail would
# spuriously mark those as failures.
#
# Usage:
#   bash scripts/cleanup-aws.sh            # destroys and verifies
#   KEEP_STATE=1 bash scripts/cleanup-aws.sh   # skip rm of .terraform/
#
# This script WILL delete real cloud resources. Run only on your own test
# account. Exits non-zero if anything tagged capstone=07 remains.

set -eu

TF_DIR="$(cd "$(dirname "$0")/../terraform/aws/ecs-fargate" && pwd)"
PROJECT_TAG="${PROJECT_TAG:-capstone-07}"
REGION="${AWS_REGION:-eu-west-1}"

echo "== capstone 07 cleanup (AWS) =="
echo "   terraform dir: $TF_DIR"
echo "   project tag:   $PROJECT_TAG"
echo "   region:        $REGION"
echo

if [ ! -f "$TF_DIR/terraform.tfstate" ] && [ ! -d "$TF_DIR/.terraform" ]; then
  echo "WARN: no terraform state in $TF_DIR; skipping destroy."
else
  (
    cd "$TF_DIR"
    terraform init -backend=false -input=false >/dev/null
    terraform destroy -auto-approve
  )
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "WARN: aws CLI not found; skipping residual-resource verification."
  exit 0
fi

echo
echo "-- Verifying no residual resources tagged capstone=07 ..."
residual=$(aws resourcegroupstaggingapi get-resources \
  --region "$REGION" \
  --tag-filters "Key=capstone,Values=07" \
  --query 'ResourceTagMappingList[].ResourceARN' \
  --output text 2>/dev/null || echo "")

if [ -n "${residual// /}" ]; then
  echo "FAIL: residual resources still tagged capstone=07:"
  echo "$residual"
  exit 1
fi

if [ "${KEEP_STATE:-0}" != "1" ]; then
  rm -rf "$TF_DIR/.terraform" "$TF_DIR/terraform.tfstate" "$TF_DIR/terraform.tfstate.backup" "$TF_DIR/tfplan"
fi

echo "OK: AWS stage 07 cleaned."
exit 0
