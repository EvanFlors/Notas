#!/usr/bin/env bash
# Starter — dry-run reference for provisioning Workload Identity Federation for GKE.
# Fill in TODOs. DO NOT execute against a real GCP project in this activity.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many pipelines
# below use `... | grep -q ...` and similar patterns which can produce SIGPIPE
# (exit 141) when grep finds a match early. pipefail would spuriously mark
# those as failures.

set -eu

# ---- Placeholders — never real IDs -----------------------------------------
PROJECT_ID="my-project-123"
GSA_NAME="checkout-app"
GSA_EMAIL="${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
KSA_NAMESPACE="checkout"
KSA_NAME="checkout-app"
BUCKET="checkout-assets-prod"

echo "=== DRY-RUN REFERENCE — do NOT execute against a real GCP project ==="
echo "    This script documents the gcloud/kubectl sequence that the"
echo "    platform team would run in Phase 4 against a real project."
echo

# ---- 1) Create the Google Service Account ----------------------------------
# TODO: uncomment in Phase 4 when running against a real project.
: <<'DRYRUN'
gcloud iam service-accounts create "${GSA_NAME}" \
  --project="${PROJECT_ID}" \
  --display-name="Checkout app runtime"
DRYRUN
echo "would run: gcloud iam service-accounts create ${GSA_NAME} --project=${PROJECT_ID}"

# ---- 2) Grant the GSA the roles it needs on target resources ---------------
# Grant object-viewer on the specific bucket (not project-wide).
: <<'DRYRUN'
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET}" \
  --member="serviceAccount:${GSA_EMAIL}" \
  --role="roles/storage.objectViewer"
DRYRUN
echo "would run: gcloud storage buckets add-iam-policy-binding gs://${BUCKET} \
--member=serviceAccount:${GSA_EMAIL} --role=roles/storage.objectViewer"

# ---- 3) Bind the special principal to roles/iam.workloadIdentityUser -------
# The special principal is:
#   serviceAccount:<project>.svc.id.goog[<namespace>/<ksa>]
: <<'DRYRUN'
gcloud iam service-accounts add-iam-policy-binding "${GSA_EMAIL}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${KSA_NAMESPACE}/${KSA_NAME}]"
DRYRUN
echo "would run: gcloud iam service-accounts add-iam-policy-binding ${GSA_EMAIL} \
--role=roles/iam.workloadIdentityUser \
--member=serviceAccount:${PROJECT_ID}.svc.id.goog[${KSA_NAMESPACE}/${KSA_NAME}]"

# ---- 4) Apply the K8s ServiceAccount with the WIF annotation ---------------
# Either apply the YAML (preferred, GitOps-friendly) OR annotate imperatively.
: <<'DRYRUN'
kubectl apply -f ../k8s/serviceaccount-and-deployment.yaml

# Alternatively:
kubectl annotate serviceaccount "${KSA_NAME}" \
  --namespace="${KSA_NAMESPACE}" \
  iam.gke.io/gcp-service-account="${GSA_EMAIL}" \
  --overwrite
DRYRUN
echo "would run: kubectl apply -f ../k8s/serviceaccount-and-deployment.yaml"
echo "    (or kubectl annotate serviceaccount ${KSA_NAME} -n ${KSA_NAMESPACE} iam.gke.io/gcp-service-account=${GSA_EMAIL} --overwrite)"

# ---- 5) Verification (optional, requires a real GKE cluster + kubectl) -----
# Inside a pod using the SA:
#   kubectl exec -n ${KSA_NAMESPACE} deploy/checkout-app -- \
#     curl -s -H "Metadata-Flavor: Google" \
#     http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email
# Expected output: ${GSA_EMAIL}

echo
echo "=== DRY-RUN REFERENCE complete. No GCP API was called. ==="
