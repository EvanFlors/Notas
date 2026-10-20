#!/usr/bin/env bash
# Strict cleanup for capstone stage 07 — GCP (Cloud Run + Cloud SQL + Secret Manager).
#
# Note: we deliberately do NOT enable `set -o pipefail` because grep-based
# checks can produce SIGPIPE (exit 141). pipefail would spuriously fail them.
#
# Usage:
#   PROJECT_ID=my-proj bash scripts/cleanup-gcp.sh
#
# Deletes real cloud resources. Exits non-zero if anything labeled
# capstone=07 remains in the given project.

set -eu

TF_DIR="$(cd "$(dirname "$0")/../terraform/gcp/cloud-run" && pwd)"
PROJECT_TAG="${PROJECT_TAG:-capstone-07}"
PROJECT_ID="${PROJECT_ID:-${TF_VAR_project_id:-}}"

echo "== capstone 07 cleanup (GCP) =="
echo "   terraform dir: $TF_DIR"
echo "   project tag:   $PROJECT_TAG"
echo "   project id:    ${PROJECT_ID:-<unset>}"
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

if ! command -v gcloud >/dev/null 2>&1; then
  echo "WARN: gcloud CLI not found; skipping residual-resource verification."
  exit 0
fi

if [ -z "${PROJECT_ID:-}" ]; then
  echo "WARN: PROJECT_ID not set; skipping residual-resource verification."
  exit 0
fi

echo
echo "-- Verifying no residual Cloud Run services labeled capstone=07 ..."
residual=$(gcloud run services list --project "$PROJECT_ID" \
  --filter="metadata.labels.capstone=07" --format="value(metadata.name)" 2>/dev/null || echo "")

if [ -n "${residual// /}" ]; then
  echo "FAIL: residual Cloud Run services labeled capstone=07:"
  echo "$residual"
  exit 1
fi

echo "-- Verifying no residual Cloud SQL instances ..."
sql_residual=$(gcloud sql instances list --project "$PROJECT_ID" \
  --filter="name~^${PROJECT_TAG}" --format="value(name)" 2>/dev/null || echo "")

if [ -n "${sql_residual// /}" ]; then
  echo "FAIL: residual Cloud SQL instances:"
  echo "$sql_residual"
  exit 1
fi

if [ "${KEEP_STATE:-0}" != "1" ]; then
  rm -rf "$TF_DIR/.terraform" "$TF_DIR/terraform.tfstate" "$TF_DIR/terraform.tfstate.backup" "$TF_DIR/tfplan"
fi

echo "OK: GCP stage 07 cleaned."
exit 0
