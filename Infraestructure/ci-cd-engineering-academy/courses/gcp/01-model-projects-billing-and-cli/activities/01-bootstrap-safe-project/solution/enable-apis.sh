#!/usr/bin/env bash
# Habilita el set minimo de APIs de un project GCP nuevo.
# NO ejecutar contra un project real sin governance aplicada. Placeholder: my-project-123.
#
# Nota: deliberadamente NO usamos `set -o pipefail` porque los chequeos
# posteriores con `... | grep -q ...` pueden producir SIGPIPE (exit 141)
# cuando grep encuentra una coincidencia temprano; pipefail marcaria esos
# como fallos espurios.

set -eu

PROJECT_ID="${PROJECT_ID:-my-project-123}"

APIS=(
  cloudresourcemanager.googleapis.com
  iam.googleapis.com
  iamcredentials.googleapis.com
  serviceusage.googleapis.com
  cloudbilling.googleapis.com
  logging.googleapis.com
  monitoring.googleapis.com
)

echo "Enabling minimal APIs on project ${PROJECT_ID}..."
for api in "${APIS[@]}"; do
  echo "  - ${api}"
  gcloud services enable "${api}" --project="${PROJECT_ID}"
done

echo
echo "Done. Verify with:"
echo "  gcloud services list --enabled --project=${PROJECT_ID}"
