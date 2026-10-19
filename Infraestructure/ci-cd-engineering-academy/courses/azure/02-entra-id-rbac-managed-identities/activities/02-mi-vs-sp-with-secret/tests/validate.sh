#!/usr/bin/env bash
# Structural validation for az-02-02-mi-vs-sp-with-secret.
#
# Checks that main.tf, main-antipattern.tf, variables.tf and
# README-INTENT.md exist and contain the required HCL blocks and
# README sections. Validates "shape" by grep — does NOT call
# `terraform init`, `terraform validate` or `terraform plan`,
# does NOT need Azure credentials, does NOT apply anything.
#
# Also enforces: no real UUIDs in HCL (encourage placeholders),
# no obvious client secret / password / pwd in the recommended
# main.tf (they belong only in main-antipattern.tf).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many
# checks use `... | grep -q ...` which can produce SIGPIPE (exit 141)
# when grep finds a match early. pipefail would spuriously mark those
# as failures.

set -eu

BASE="${1:-/tmp/az-02-misp}"
issues=0

echo "== Structural validation for $BASE =="

check_file_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
    return 0
  else
    echo "  FAIL $f does not exist"
    issues=$((issues+1))
    return 1
  fi
}

check_grep() {
  local f="$1"
  local pattern="$2"
  local label="$3"
  if grep -qE "$pattern" "$f"; then
    echo "  OK   $(basename "$f"): ${label}"
  else
    echo "  FAIL $(basename "$f"): ${label} (pattern: $pattern)"
    issues=$((issues+1))
  fi
}

check_no_grep() {
  local f="$1"
  local pattern="$2"
  local label="$3"
  if grep -qE "$pattern" "$f"; then
    echo "  FAIL $(basename "$f"): ${label} (unexpected pattern present: $pattern)"
    issues=$((issues+1))
  else
    echo "  OK   $(basename "$f"): ${label}"
  fi
}

# ---------- main.tf (recommended: Managed Identity) ------------------
MAIN="$BASE/main.tf"
if check_file_exists "$MAIN"; then
  check_grep "$MAIN" 'required_providers' 'declares required_providers'
  check_grep "$MAIN" 'hashicorp/azurerm' 'uses hashicorp/azurerm provider'
  check_grep "$MAIN" 'provider[[:space:]]+"azurerm"' 'has provider "azurerm" block'
  check_grep "$MAIN" 'resource[[:space:]]+"azurerm_resource_group"' 'has azurerm_resource_group'
  check_grep "$MAIN" 'resource[[:space:]]+"azurerm_user_assigned_identity"' 'has azurerm_user_assigned_identity'
  check_grep "$MAIN" 'resource[[:space:]]+"azurerm_key_vault"' 'has azurerm_key_vault'
  check_grep "$MAIN" 'enable_rbac_authorization[[:space:]]*=[[:space:]]*true' 'key vault uses RBAC data-plane'
  check_grep "$MAIN" 'resource[[:space:]]+"azurerm_role_assignment"' 'has azurerm_role_assignment'
  check_grep "$MAIN" '"Key Vault Secrets User"' 'role_definition_name = "Key Vault Secrets User"'
  check_grep "$MAIN" 'resource[[:space:]]+"azurerm_linux_virtual_machine"' 'has azurerm_linux_virtual_machine'
  check_grep "$MAIN" 'identity[[:space:]]*\{' 'VM has an identity {...} block'
  check_grep "$MAIN" 'type[[:space:]]*=[[:space:]]*"UserAssigned"' 'identity type = "UserAssigned"'
  check_grep "$MAIN" 'principal_id[[:space:]]*=[[:space:]]*azurerm_user_assigned_identity' 'role_assignment uses MI principal_id'

  # NO secret-ish fields in the recommended main.tf.
  check_no_grep "$MAIN" 'client_secret' 'no client_secret in main.tf (would defeat the pattern)'
  check_no_grep "$MAIN" 'service_principal_password' 'no service_principal_password in main.tf'
  check_no_grep "$MAIN" 'application_password' 'no application_password in main.tf'
  # The admin_ssh_key placeholder contains the harmless literal "PUBLIC-KEY",
  # which is fine; we check that nothing claims to be a real-looking GUID
  # tenant/subscription id.
  check_no_grep "$MAIN" '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' \
    'no real-looking UUID in main.tf (use placeholders)'
fi

# ---------- main-antipattern.tf (SPN + secret) -----------------------
ANT="$BASE/main-antipattern.tf"
if check_file_exists "$ANT"; then
  check_grep "$ANT" 'ANTI[- ]?PATTERN|ANTIPATRON' 'file clearly marked as ANTI-PATTERN / ANTIPATRON'
  check_grep "$ANT" 'resource[[:space:]]+"(azuread_application|azurerm_application)"' 'has application resource'
  check_grep "$ANT" 'resource[[:space:]]+"(azuread_service_principal|azurerm_service_principal)"' 'has service_principal resource'
  check_grep "$ANT" 'resource[[:space:]]+"(azuread_service_principal_password|azuread_application_password|azurerm_service_principal_password)"' \
    'has a *_password resource (client secret of the SPN)'
  check_grep "$ANT" 'resource[[:space:]]+"azurerm_key_vault"' 'has azurerm_key_vault for 1:1 comparison'
  check_grep "$ANT" 'resource[[:space:]]+"azurerm_role_assignment"' 'has azurerm_role_assignment for 1:1 comparison'
  check_grep "$ANT" '"Key Vault Secrets User"' 'role_definition_name = "Key Vault Secrets User"'
  check_no_grep "$ANT" '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' \
    'no real-looking UUID in main-antipattern.tf (use placeholders)'
fi

# ---------- variables.tf ---------------------------------------------
VARS="$BASE/variables.tf"
if check_file_exists "$VARS"; then
  check_grep "$VARS" 'variable[[:space:]]+"location"' 'declares variable "location"'
  check_grep "$VARS" 'default[[:space:]]*=[[:space:]]*"(westeurope|northeurope|francecentral|germanywestcentral|swedencentral|norwayeast|switzerlandnorth|uksouth|ukwest|eu-?[a-z]+)"' \
    'location default is a European region'
  check_no_grep "$VARS" 'client_secret' 'no client_secret in variables.tf'
  check_no_grep "$VARS" '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' \
    'no real-looking UUID in variables.tf'
fi

# ---------- README-INTENT.md ----------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  for pattern in \
    'Escenario +recomendado' \
    'Antipatron|Anti[- ]?patr[oó]n|Service +Principal' \
    'Comparaci[oó]n' \
    'Jerarqu[ií]a +de +credenciales'; do
    if grep -qiE "^#+ .*(${pattern})" "$DOC"; then
      echo "  OK   README-INTENT.md has section matching '${pattern}'"
    else
      echo "  FAIL README-INTENT.md missing section matching '${pattern}'"
      issues=$((issues+1))
    fi
  done

  for mention in \
    'Managed +Identity' \
    'Service +Principal' \
    'Key +Vault' \
    'IMDS'; do
    if grep -qiE "$mention" "$DOC"; then
      echo "  OK   README-INTENT.md mentions ${mention}"
    else
      echo "  FAIL README-INTENT.md does not mention ${mention}"
      issues=$((issues+1))
    fi
  done

  # 4 axes mentioned at least once.
  axes=0
  for axis in \
    'rotaci[oó]n' \
    'blast +radius' \
    'auditab' \
    'recuperaci[oó]n'; do
    if grep -qiE "$axis" "$DOC"; then
      axes=$((axes+1))
    fi
  done
  if [ "$axes" -ge 4 ]; then
    echo "  OK   README-INTENT.md mentions the 4 comparison axes (${axes}/4)"
  else
    echo "  FAIL README-INTENT.md mentions only ${axes}/4 comparison axes"
    issues=$((issues+1))
  fi

  if grep -qiE 'no se ha aplicado|no.aplic|placeholder|no.credencial' "$DOC"; then
    echo "  OK   README-INTENT.md states nothing was applied / uses placeholders"
  else
    echo "  FAIL README-INTENT.md does not state the no-apply / placeholder caveat"
    issues=$((issues+1))
  fi
fi

echo
if [ "$issues" -gt 0 ]; then
  echo "RESULT: $issues issue(s)."
  echo "        (Semantic correctness in a real Azure tenant is NOT verified here.)"
  exit 1
fi
echo "RESULT: 0 issue(s). Structural validation passed."
echo "        Compare with solution/ for self-assessment."
exit 0
