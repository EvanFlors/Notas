#!/usr/bin/env bash
# Structural validation for az-06-01-capstone-secrets-via-kv.
#
# Checks that main.tf + variables.tf + role-assignment-kv-secrets-user.json
# + README-INTENT.md exist and carry the minimum structure required by the
# brief: RBAC data-plane Key Vault, User-Assigned MI, role assignment with
# the right role + scope + principal, and a JSON role assignment with the
# built-in GUID of "Key Vault Secrets User".
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real Azure subscription — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/az-06-01}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: 'jq' is required but not installed."
  exit 2
fi

check_file_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
    return 0
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
    return 1
  fi
}

check_grep() {
  local f="$1"
  local pat="$2"
  local label="$3"
  if grep -qE "$pat" "$f"; then
    echo "  OK   $(basename "$f"): ${label}"
  else
    echo "  FAIL $(basename "$f"): ${label} (pattern: $pat)"
    fail=$((fail+1))
  fi
}

check_jq_contains() {
  local f="$1"
  local expr="$2"
  local label="$3"
  local val
  val=$(jq -r "$expr" "$f" 2>/dev/null || echo "")
  if [ "$val" = "true" ]; then
    echo "  OK   $(basename "$f"): ${label}"
  else
    echo "  FAIL $(basename "$f"): ${label} (expr: $expr)"
    fail=$((fail+1))
  fi
}

# --- main.tf -------------------------------------------------------------
F_MAIN="$BASE/main.tf"
if check_file_exists "$F_MAIN"; then
  check_grep "$F_MAIN" 'provider +"azurerm"' 'declares azurerm provider'
  check_grep "$F_MAIN" 'resource +"azurerm_resource_group"' 'declares azurerm_resource_group'
  check_grep "$F_MAIN" 'resource +"azurerm_user_assigned_identity"' 'declares azurerm_user_assigned_identity'
  check_grep "$F_MAIN" 'resource +"azurerm_key_vault"' 'declares azurerm_key_vault'
  check_grep "$F_MAIN" 'enable_rbac_authorization[[:space:]]*=[[:space:]]*true' 'uses enable_rbac_authorization = true (RBAC data-plane)'
  check_grep "$F_MAIN" 'resource +"azurerm_role_assignment"' 'declares azurerm_role_assignment'
  check_grep "$F_MAIN" '"Key Vault Secrets User"' 'role assignment references "Key Vault Secrets User"'
  check_grep "$F_MAIN" 'principal_id[[:space:]]*=[[:space:]]*azurerm_user_assigned_identity\.[a-zA-Z0-9_]+\.principal_id' 'role assignment uses .principal_id (NOT .client_id)'
  check_grep "$F_MAIN" 'scope[[:space:]]*=[[:space:]]*azurerm_key_vault\.[a-zA-Z0-9_]+\.id' 'role assignment scoped to the key vault (not the RG)'
  check_grep "$F_MAIN" 'resource +"azurerm_key_vault_secret"' 'declares a key vault secret (dummy)'
  # Reject obvious real-secret patterns in the secret value.
  if grep -qE 'value[[:space:]]*=[[:space:]]*"CHANGE-ME-DUMMY-NOT-A-REAL-SECRET"' "$F_MAIN"; then
    echo "  OK   main.tf: secret uses the DUMMY placeholder value"
  else
    echo "  FAIL main.tf: secret must use value = \"CHANGE-ME-DUMMY-NOT-A-REAL-SECRET\" (dummy placeholder)"
    fail=$((fail+1))
  fi
  # Guard against access_policy block coexisting (classic footgun).
  if grep -qE '^\s*access_policy\s*{' "$F_MAIN"; then
    echo "  FAIL main.tf: contains access_policy block — remove it, this design uses RBAC data-plane"
    fail=$((fail+1))
  else
    echo "  OK   main.tf: no legacy access_policy block"
  fi
fi

# --- variables.tf --------------------------------------------------------
F_VARS="$BASE/variables.tf"
if check_file_exists "$F_VARS"; then
  for v in "location" "resource_group_name" "key_vault_name" "identity_name"; do
    check_grep "$F_VARS" "variable +\"${v}\"" "declares variable \"${v}\""
  done
fi

# --- role-assignment-kv-secrets-user.json --------------------------------
F_JSON="$BASE/role-assignment-kv-secrets-user.json"
if check_file_exists "$F_JSON"; then
  if jq empty "$F_JSON" >/dev/null 2>&1; then
    echo "  OK   $F_JSON is valid JSON"
  else
    echo "  FAIL $F_JSON is not valid JSON"
    fail=$((fail+1))
  fi
  check_jq_contains "$F_JSON" 'has("principalId")'       'has principalId'
  check_jq_contains "$F_JSON" 'has("roleDefinitionId")'  'has roleDefinitionId'
  check_jq_contains "$F_JSON" 'has("scope")'             'has scope'
  check_jq_contains "$F_JSON" '.principalType == "ServicePrincipal"' 'principalType == "ServicePrincipal"'
  # Role def must end in the Key Vault Secrets User built-in GUID.
  check_jq_contains "$F_JSON" \
    '.roleDefinitionId | endswith("4633458b-17de-408a-b874-0445c86b69e6")' \
    'roleDefinitionId ends with Key Vault Secrets User GUID'
  # Scope must point to a Key Vault vault.
  check_jq_contains "$F_JSON" \
    '.scope | contains("Microsoft.KeyVault/vaults/")' \
    'scope points to Microsoft.KeyVault/vaults/<name> (vault scope, not RG)'
fi

# --- README-INTENT.md ----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  for section in "key-vault" "managed-identity" "role-assignment"; do
    if grep -qE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section for ${section}"
    else
      echo "  FAIL README-INTENT.md missing section for ${section}"
      fail=$((fail+1))
    fi
  done
  if grep -qiE 'RBAC +data-plane|RBAC +dataplane|data-plane +RBAC' "$DOC"; then
    echo "  OK   README-INTENT.md mentions RBAC data-plane"
  else
    echo "  FAIL README-INTENT.md does not mention 'RBAC data-plane'"
    fail=$((fail+1))
  fi
  if grep -qiE 'Managed +Identity' "$DOC"; then
    echo "  OK   README-INTENT.md mentions Managed Identity"
  else
    echo "  FAIL README-INTENT.md does not mention 'Managed Identity'"
    fail=$((fail+1))
  fi
  if grep -q 'Key Vault Secrets User' "$DOC"; then
    echo "  OK   README-INTENT.md mentions 'Key Vault Secrets User'"
  else
    echo "  FAIL README-INTENT.md does not mention 'Key Vault Secrets User'"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s)."
  echo "        (Semantic correctness in a real Azure subscription is NOT verified here.)"
  exit 1
fi
echo "RESULT: 0 issue(s). HCL, JSON y README-INTENT.md pasan validacion estructural."
echo "        Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
