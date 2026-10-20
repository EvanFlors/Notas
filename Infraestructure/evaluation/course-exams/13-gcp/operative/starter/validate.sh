#!/usr/bin/env bash
# Validates the operative exam answer. Run from operative/answer/.
# Usage: ../starter/validate.sh
set -euo pipefail

STARTER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> terraform fmt -check"
terraform fmt -check -recursive

echo "==> terraform init -backend=false"
terraform init -backend=false -input=false >/dev/null

echo "==> terraform validate"
terraform validate

echo "==> terraform plan"
terraform plan -input=false -out=tfplan.binary -var-file="${STARTER}/example.tfvars" >/dev/null
terraform show -json tfplan.binary > tfplan.json

echo "==> tflint"
tflint --config="${STARTER}/.tflint.hcl" --format=compact

echo "==> checkov"
checkov -d . --config-file "${STARTER}/.checkov.yaml" --quiet --compact || {
  echo "checkov reported findings; review above."
  exit 1
}

echo "==> assertions"

jq -e '
  [.planned_values.root_module.resources[]
   | select(.type == "google_iam_workload_identity_pool_provider")
   | .values.attribute_condition]
  | length > 0 and (.[0] | test("assertion.repository ==") and test("assertion.ref =="))
' tfplan.json >/dev/null && echo "  OK: WIF double attribute condition"

jq -e '
  [.planned_values.root_module.resources[]
   | select(.type == "google_binary_authorization_policy")
   | .values.default_admission_rule[0].evaluation_mode]
  | .[0] == "REQUIRE_ATTESTATION"
' tfplan.json >/dev/null && echo "  OK: Binauthz REQUIRE_ATTESTATION"

jq -e '
  [.planned_values.root_module.resources[]
   | select(.type | startswith("google_"))
   | select(.type | contains("iam"))
   | .values.role? // empty]
  | all(test("roles/(owner|editor)$") | not)
' tfplan.json >/dev/null && echo "  OK: no basic roles granted"

jq -e '
  [.planned_values.root_module.resources[]
   | select(.type == "google_logging_project_sink")
   | .values.unique_writer_identity]
  | .[0] == true
' tfplan.json >/dev/null && echo "  OK: sink uses unique_writer_identity"

echo "==> ALL CHECKS PASSED"
