#!/usr/bin/env bash
# Strict cleanup for capstone stage 07 — Azure (Container Apps + Postgres + Key Vault).
#
# Note: we deliberately do NOT enable `set -o pipefail` because grep-based
# checks can emit SIGPIPE (exit 141). pipefail would mark them as failures.
#
# Usage:
#   bash scripts/cleanup-azure.sh
#
# Deletes real cloud resources. Exits non-zero if the capstone resource group
# still exists afterwards.

set -eu

TF_DIR="$(cd "$(dirname "$0")/../terraform/azure/container-apps" && pwd)"
PROJECT_TAG="${PROJECT_TAG:-capstone-07}"
RG_NAME="${RG_NAME:-rg-${PROJECT_TAG}}"

echo "== capstone 07 cleanup (Azure) =="
echo "   terraform dir: $TF_DIR"
echo "   project tag:   $PROJECT_TAG"
echo "   resource grp:  $RG_NAME"
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

if ! command -v az >/dev/null 2>&1; then
  echo "WARN: az CLI not found; skipping residual-resource verification."
  exit 0
fi

echo
echo "-- Verifying resource group ${RG_NAME} is gone ..."
exists=$(az group exists --name "$RG_NAME" 2>/dev/null || echo "false")
if [ "$exists" = "true" ]; then
  echo "WARN: resource group $RG_NAME still exists; forcing delete."
  az group delete --name "$RG_NAME" --yes --no-wait
  echo "FAIL: deletion requested asynchronously; re-run cleanup after Azure finishes."
  exit 1
fi

# Soft-deleted Key Vault remains for retention_days; purge it to free the name.
kv_name="kv${PROJECT_TAG//-/}"
if az keyvault list-deleted --query "[?name=='$kv_name'] | [0].name" -o tsv 2>/dev/null | grep -q .; then
  echo "-- Purging soft-deleted Key Vault $kv_name ..."
  az keyvault purge --name "$kv_name" || true
fi

if [ "${KEEP_STATE:-0}" != "1" ]; then
  rm -rf "$TF_DIR/.terraform" "$TF_DIR/terraform.tfstate" "$TF_DIR/terraform.tfstate.backup" "$TF_DIR/tfplan"
fi

echo "OK: Azure stage 07 cleaned."
exit 0
