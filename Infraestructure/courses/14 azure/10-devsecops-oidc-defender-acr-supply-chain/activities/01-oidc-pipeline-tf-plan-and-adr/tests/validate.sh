#!/usr/bin/env bash
# Structural validation for az-10-01-oidc-pipeline-tf-plan-and-adr.
# Checks that the ADR, Terraform plan-only files, and GitHub Actions workflow
# exist and carry the required literal fields (OIDC subject, ACR SKU,
# Defender for Containers plan, azure/login without client-secret, etc.).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT run `terraform init/apply` nor talk to Azure. Semantic correctness
# must be compared against solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/az-10-01}"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: base directory $BASE does not exist. Student must create it."
  exit 1
fi

# --- ADR -----------------------------------------------------------------
DOC="$BASE/ADR-DEVSECOPS-SUPPLY-CHAIN.md"
if [ ! -f "$DOC" ]; then
  echo "  FAIL $DOC does not exist"
  fail=$((fail+1))
else
  echo "  OK   $DOC exists"

  if grep -qiE '^#+ *ADR' "$DOC"; then
    echo "  OK   ADR has an 'ADR' heading"
  else
    echo "  FAIL ADR missing an 'ADR' heading"
    fail=$((fail+1))
  fi

  for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
                 "Consecuencias|Consequences" "Alternativas|Alternatives"; do
    label="${section%%|*}"
    if grep -qiE "^#+ *(${section})\\b" "$DOC"; then
      echo "  OK   ADR has '${label}' section"
    else
      echo "  FAIL ADR missing '${label}' section"
      fail=$((fail+1))
    fi
  done

  for tok in "OIDC" "federated" "GitHub +Actions|GHA" "ACR|Container +Registry" \
             "Defender" "cosign|sigstore" "Entra|Azure +AD" "app +registration"; do
    label="${tok%%|*}"
    if grep -qiE "$tok" "$DOC"; then
      echo "  OK   ADR mentions '${label}'"
    else
      echo "  FAIL ADR does not mention '${label}'"
      fail=$((fail+1))
    fi
  done

  # Subject claim with repo:... form
  if grep -qE 'repo:[A-Za-z0-9_.\/-]+:(ref|environment|pull_request|job_workflow_ref)' "$DOC"; then
    echo "  OK   ADR mentions a concrete subject claim (repo:...:ref/environment)"
  else
    echo "  FAIL ADR does not mention a concrete OIDC subject claim (expected 'repo:owner/repo:ref:...' or ':environment:...')"
    fail=$((fail+1))
  fi

  # Alternatives: at least 2 subheadings or 2 numbered items
  alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
  alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
  if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
    echo "  OK   ADR lists at least 2 alternatives"
  else
    echo "  FAIL ADR lists fewer than 2 alternatives"
    fail=$((fail+1))
  fi
fi

# --- Terraform plan-only -------------------------------------------------
TF_DIR="$BASE/terraform"
if [ ! -d "$TF_DIR" ]; then
  echo "  FAIL $TF_DIR does not exist"
  fail=$((fail+1))
else
  for f in main.tf oidc.tf acr.tf defender.tf; do
    if [ -f "$TF_DIR/$f" ]; then
      echo "  OK   terraform/$f exists"
    else
      echo "  FAIL terraform/$f does not exist"
      fail=$((fail+1))
    fi
  done

  # oidc.tf expected fields
  OIDC="$TF_DIR/oidc.tf"
  if [ -f "$OIDC" ]; then
    if grep -qE 'resource +"azuread_application"' "$OIDC"; then
      echo "  OK   oidc.tf declares azuread_application"
    else
      echo "  FAIL oidc.tf missing azuread_application resource"
      fail=$((fail+1))
    fi
    if grep -qE 'resource +"azuread_service_principal"' "$OIDC"; then
      echo "  OK   oidc.tf declares azuread_service_principal"
    else
      echo "  FAIL oidc.tf missing azuread_service_principal resource"
      fail=$((fail+1))
    fi
    if grep -qE 'resource +"azuread_application_federated_identity_credential"' "$OIDC"; then
      echo "  OK   oidc.tf declares azuread_application_federated_identity_credential"
    else
      echo "  FAIL oidc.tf missing azuread_application_federated_identity_credential resource"
      fail=$((fail+1))
    fi
    if grep -qF 'https://token.actions.githubusercontent.com' "$OIDC"; then
      echo "  OK   oidc.tf pins issuer to GitHub Actions OIDC"
    else
      echo "  FAIL oidc.tf does not pin issuer https://token.actions.githubusercontent.com"
      fail=$((fail+1))
    fi
    if grep -qF 'api://AzureADTokenExchange' "$OIDC"; then
      echo "  OK   oidc.tf declares audience api://AzureADTokenExchange"
    else
      echo "  FAIL oidc.tf missing audience api://AzureADTokenExchange"
      fail=$((fail+1))
    fi
    if grep -qE 'subject[[:space:]]*=[[:space:]]*"repo:' "$OIDC"; then
      echo "  OK   oidc.tf declares subject starting with 'repo:'"
    else
      echo "  FAIL oidc.tf missing subject = \"repo:...\" field"
      fail=$((fail+1))
    fi
  fi

  # acr.tf expected fields
  ACR="$TF_DIR/acr.tf"
  if [ -f "$ACR" ]; then
    if grep -qE 'resource +"azurerm_container_registry"' "$ACR"; then
      echo "  OK   acr.tf declares azurerm_container_registry"
    else
      echo "  FAIL acr.tf missing azurerm_container_registry resource"
      fail=$((fail+1))
    fi
    if grep -qE 'sku[[:space:]]*=[[:space:]]*"(Premium|Standard|Basic)"' "$ACR"; then
      echo "  OK   acr.tf declares a sku"
    else
      echo "  FAIL acr.tf missing sku = \"Premium|Standard|Basic\""
      fail=$((fail+1))
    fi
    if grep -qE 'admin_enabled[[:space:]]*=[[:space:]]*false' "$ACR"; then
      echo "  OK   acr.tf disables admin user (admin_enabled = false)"
    else
      echo "  FAIL acr.tf must set admin_enabled = false (never true)"
      fail=$((fail+1))
    fi
  fi

  # defender.tf expected fields
  DEF="$TF_DIR/defender.tf"
  if [ -f "$DEF" ]; then
    if grep -qE 'resource +"azurerm_security_center_subscription_pricing"' "$DEF"; then
      echo "  OK   defender.tf declares azurerm_security_center_subscription_pricing"
    else
      echo "  FAIL defender.tf missing azurerm_security_center_subscription_pricing resource"
      fail=$((fail+1))
    fi
    if grep -qE 'resource_type[[:space:]]*=[[:space:]]*"Containers"' "$DEF"; then
      echo "  OK   defender.tf targets resource_type = \"Containers\""
    else
      echo "  FAIL defender.tf must target resource_type = \"Containers\""
      fail=$((fail+1))
    fi
    if grep -qE 'tier[[:space:]]*=[[:space:]]*"Standard"' "$DEF"; then
      echo "  OK   defender.tf enables tier = \"Standard\""
    else
      echo "  FAIL defender.tf must set tier = \"Standard\" to actually enable the plan"
      fail=$((fail+1))
    fi
  fi

  # NO real secrets in any .tf file. Strip comments (# ...) before scanning so
  # didactic lines like "# No client_secret anywhere." do not false-positive.
  secrets_found=0
  for tf in "$TF_DIR"/*.tf; do
    [ -f "$tf" ] || continue
    if sed 's/#.*$//' "$tf" | grep -qE 'client_secret[[:space:]]*=|client-secret[[:space:]]*=|AZURE_CREDENTIALS|password[[:space:]]*=[[:space:]]*"[^"]+"'; then
      echo "  FAIL $(basename "$tf") contains forbidden secret-looking fields"
      fail=$((fail+1))
      secrets_found=$((secrets_found+1))
    fi
  done
  if [ "$secrets_found" -eq 0 ]; then
    echo "  OK   no client_secret / AZURE_CREDENTIALS in terraform/*.tf"
  fi
fi

# --- GitHub Actions workflow ---------------------------------------------
WF="$BASE/.github/workflows/build-sign-push.yml"
if [ ! -f "$WF" ]; then
  echo "  FAIL $WF does not exist"
  fail=$((fail+1))
else
  echo "  OK   workflow $WF exists"

  if grep -qE 'id-token:[[:space:]]*write' "$WF"; then
    echo "  OK   workflow declares permissions.id-token: write"
  else
    echo "  FAIL workflow missing 'id-token: write' permission"
    fail=$((fail+1))
  fi
  if grep -qE 'uses:[[:space:]]*azure/login@' "$WF"; then
    echo "  OK   workflow uses azure/login@"
  else
    echo "  FAIL workflow does not use azure/login@..."
    fail=$((fail+1))
  fi
  for v in "client-id" "tenant-id" "subscription-id"; do
    if grep -qE "${v}:" "$WF"; then
      echo "  OK   workflow passes ${v}"
    else
      echo "  FAIL workflow missing ${v}"
      fail=$((fail+1))
    fi
  done
  # Must NOT contain client-secret or AZURE_CREDENTIALS
  if grep -qE 'client-secret|AZURE_CREDENTIALS|creds:' "$WF"; then
    echo "  FAIL workflow contains forbidden fields (client-secret / AZURE_CREDENTIALS / creds:) — defeats OIDC purpose"
    fail=$((fail+1))
  else
    echo "  OK   workflow has no client-secret / AZURE_CREDENTIALS (true OIDC)"
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
