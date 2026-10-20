#!/usr/bin/env bash
# Structural validation for az-07-01-provision-aks-and-run-app.
#
# Checks that the 4 deliverables exist and contain the required markers.
# Optionally runs `terraform validate` if terraform is on PATH.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/az-07-01}"
TF="$BASE/terraform/main.tf"
APP="$BASE/k8s/app.yaml"
PLAN="$BASE/docs/AKS_PLAN.md"
ADR="$BASE/docs/ADR.md"
fail=0

echo "== Structural validation for $BASE =="

for f in "$TF" "$APP" "$PLAN" "$ADR"; do
  if [ -f "$f" ]; then
    echo "  OK   exists: ${f#$BASE/}"
  else
    echo "  FAIL missing: ${f#$BASE/}"
    fail=$((fail+1))
  fi
done

# Terraform content markers.
if [ -f "$TF" ]; then
  for marker in \
      "azurerm_kubernetes_cluster" \
      "oidc_issuer_enabled" \
      "workload_identity_enabled" \
      "default_node_pool" \
      "azurerm_kubernetes_cluster_node_pool" \
      "network_plugin_mode" \
      "azure_active_directory_role_based_access_control" \
      "local_account_disabled" \
      "azurerm_user_assigned_identity"; do
    if grep -q "$marker" "$TF"; then
      echo "  OK   main.tf mentions '$marker'"
    else
      echo "  FAIL main.tf missing '$marker'"
      fail=$((fail+1))
    fi
  done

  # Must use the canonical placeholder subscription id.
  if grep -q "00000000-0000-0000-0000-000000000000" "$TF"; then
    echo "  OK   main.tf uses canonical placeholder subscription_id"
  else
    echo "  FAIL main.tf should use subscription_id 00000000-0000-0000-0000-000000000000"
    fail=$((fail+1))
  fi

  # Reject obvious real-looking UUIDs: any UUID whose blocks are not all
  # 00000000... / 11111111... / 22222222... etc. We allow placeholder repeating
  # patterns; anything else looks like a leaked real id.
  bad_uuid=$(grep -oE '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' "$TF" \
             | grep -vE '^([0-9a-f])\1{7}-\1{4}-\1{4}-\1{4}-\1{12}$' || true)
  if [ -z "$bad_uuid" ]; then
    echo "  OK   main.tf has no real-looking UUIDs"
  else
    echo "  FAIL main.tf contains non-placeholder UUIDs (possible leak): $bad_uuid"
    fail=$((fail+1))
  fi
fi

# K8s manifests.
if [ -f "$APP" ]; then
  for kind in "Deployment" "Service" "Ingress"; do
    if grep -qE "^kind: *$kind\b" "$APP"; then
      echo "  OK   app.yaml has kind: $kind"
    else
      echo "  FAIL app.yaml missing kind: $kind"
      fail=$((fail+1))
    fi
  done
fi

# AKS_PLAN.md must mention add-ons and the kind-vs-aks gap.
if [ -f "$PLAN" ]; then
  if grep -qiE 'add[- ]?on' "$PLAN"; then
    echo "  OK   AKS_PLAN.md mentions add-ons"
  else
    echo "  FAIL AKS_PLAN.md missing add-ons section"
    fail=$((fail+1))
  fi
  if grep -qiE 'kind|no prueba|no cubre|limitaci' "$PLAN"; then
    echo "  OK   AKS_PLAN.md mentions kind limitations"
  else
    echo "  FAIL AKS_PLAN.md missing 'what kind does NOT prove' discussion"
    fail=$((fail+1))
  fi
fi

# ADR: at least 3 Decision headings + 3 Rationale sections.
if [ -f "$ADR" ]; then
  dec=$(grep -cEi '^##? *Decision' "$ADR" || true)
  rat=$(grep -cEi 'Rationale' "$ADR" || true)
  if [ "$dec" -ge 3 ]; then
    echo "  OK   ADR.md has at least 3 Decision headings ($dec found)"
  else
    echo "  FAIL ADR.md has $dec Decision headings (expected >=3)"
    fail=$((fail+1))
  fi
  if [ "$rat" -ge 3 ]; then
    echo "  OK   ADR.md has at least 3 Rationale sections ($rat found)"
  else
    echo "  FAIL ADR.md has $rat Rationale sections (expected >=3)"
    fail=$((fail+1))
  fi
  # Decisions must name the keywords of the three required choices.
  for kw in "node *pool|spot|virtual node" \
            "cni|overlay|kubenet|network_plugin" \
            "entra|azure *rbac|local_account_disabled|aad"; do
    if grep -qiE "$kw" "$ADR"; then
      echo "  OK   ADR.md touches topic: $kw"
    else
      echo "  FAIL ADR.md missing topic: $kw"
      fail=$((fail+1))
    fi
  done
fi

# Optional: run terraform validate if available.
if command -v terraform >/dev/null 2>&1 && [ -f "$TF" ]; then
  echo "  .. terraform detected; running 'terraform init -backend=false && validate'"
  (
    cd "$BASE/terraform"
    terraform init -backend=false -input=false >/tmp/az-07-01-tf-init.log 2>&1 || true
    if terraform validate >/tmp/az-07-01-tf-validate.log 2>&1; then
      echo "  OK   terraform validate succeeded"
    else
      echo "  WARN terraform validate failed; see /tmp/az-07-01-tf-validate.log"
      # warning only — provider download may fail in offline sandboxes.
    fi
  )
else
  echo "  .. terraform not in PATH or no main.tf; skipping terraform validate"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara los entregables con solution/REFERENCE.md para autoevaluarte."
exit 0
