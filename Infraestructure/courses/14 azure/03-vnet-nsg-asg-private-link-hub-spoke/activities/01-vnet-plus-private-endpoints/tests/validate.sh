#!/usr/bin/env bash
# Structural validation for az-03-01-vnet-plus-private-endpoints.
# Verifies that main.tf, variables.tf, outputs.tf and ADR-VNET-DESIGN.md exist
# in the student's working directory and that they contain the required
# azurerm resources, patterns and ADR sections.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real Azure subscription — compare
# manually with solution/ADR-VNET-DESIGN.md and solution/main.tf.

set -eu

BASE="${1:-/tmp/az-03-01-vnet-pe}"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Create it and place the Terraform + ADR there."
  exit 1
fi

check_file_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $(basename "$f") exists"
    return 0
  else
    echo "  FAIL $(basename "$f") does not exist"
    fail=$((fail + 1))
    return 1
  fi
}

# Grep that cannot abort set -e when it returns 1 (no match).
grep_tf() {
  local pat="$1"
  grep -RqE "$pat" "$BASE"/*.tf 2>/dev/null && return 0 || return 1
}

check_tf_resource() {
  local label="$1"
  local pat="$2"
  if grep_tf "$pat"; then
    echo "  OK   HCL contains: $label"
  else
    echo "  FAIL HCL missing : $label  (regex: $pat)"
    fail=$((fail + 1))
  fi
}

check_doc_section() {
  local doc="$1"
  local label="$2"
  local pat="$3"
  if grep -qiE "$pat" "$doc"; then
    echo "  OK   ADR has '$label' section"
  else
    echo "  FAIL ADR missing '$label' section (regex: $pat)"
    fail=$((fail + 1))
  fi
}

# ------------------------------------------------------------------
# 1. Required files
# ------------------------------------------------------------------
check_file_exists "$BASE/main.tf"       || true
check_file_exists "$BASE/variables.tf"  || true
check_file_exists "$BASE/outputs.tf"    || true
check_file_exists "$BASE/ADR-VNET-DESIGN.md" || true

# If no main.tf there is nothing else to check.
if [ ! -f "$BASE/main.tf" ]; then
  echo
  echo "RESULT: $fail check(s) failed (no main.tf — cannot continue)."
  exit 1
fi

# ------------------------------------------------------------------
# 2. Provider declaration
# ------------------------------------------------------------------
check_tf_resource "required_providers azurerm" 'required_providers' || true
check_tf_resource "provider \"azurerm\" block" 'provider[[:space:]]+"azurerm"' || true

# ------------------------------------------------------------------
# 3. Core networking resources
# ------------------------------------------------------------------
check_tf_resource "azurerm_resource_group"       'resource[[:space:]]+"azurerm_resource_group"' || true
check_tf_resource "azurerm_virtual_network"      'resource[[:space:]]+"azurerm_virtual_network"' || true

# At least 2 subnets, one named snet-app and one named snet-pe (or similar).
snet_app=$(grep -REc 'name[[:space:]]*=[[:space:]]*"snet-app"' "$BASE"/*.tf 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
snet_pe=$(grep -REc 'name[[:space:]]*=[[:space:]]*"snet-(pe|privatelink|privateendpoints)"' "$BASE"/*.tf 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ "$snet_app" -ge 1 ]; then
  echo "  OK   HCL has a subnet named 'snet-app'"
else
  echo "  FAIL HCL has no subnet named 'snet-app'"
  fail=$((fail + 1))
fi
if [ "$snet_pe" -ge 1 ]; then
  echo "  OK   HCL has a subnet named 'snet-pe' / 'snet-privatelink' / 'snet-privateendpoints'"
else
  echo "  FAIL HCL has no subnet dedicated to Private Endpoints"
  fail=$((fail + 1))
fi

# ------------------------------------------------------------------
# 4. NSG + at least 3 rules (1 Deny, 2 Allow); ASG references
# ------------------------------------------------------------------
check_tf_resource "azurerm_network_security_group" 'resource[[:space:]]+"azurerm_network_security_group"' || true

rules=$(grep -REc 'resource[[:space:]]+"azurerm_network_security_rule"' "$BASE"/*.tf 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ "$rules" -ge 3 ]; then
  echo "  OK   HCL has >=3 azurerm_network_security_rule ($rules found)"
else
  echo "  FAIL HCL has only $rules NSG rule(s); expected >=3"
  fail=$((fail + 1))
fi

if grep_tf 'access[[:space:]]*=[[:space:]]*"Deny"'; then
  echo "  OK   HCL has at least one rule with access = \"Deny\""
else
  echo "  FAIL HCL has no rule with access = \"Deny\""
  fail=$((fail + 1))
fi
allow_count=$(grep -REc 'access[[:space:]]*=[[:space:]]*"Allow"' "$BASE"/*.tf 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ "$allow_count" -ge 2 ]; then
  echo "  OK   HCL has >=2 rules with access = \"Allow\" ($allow_count found)"
else
  echo "  FAIL HCL has only $allow_count rule(s) with access = \"Allow\" (expected >=2)"
  fail=$((fail + 1))
fi

asg_count=$(grep -REc 'resource[[:space:]]+"azurerm_application_security_group"' "$BASE"/*.tf 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ "$asg_count" -ge 2 ]; then
  echo "  OK   HCL has >=2 azurerm_application_security_group ($asg_count found)"
else
  echo "  FAIL HCL has only $asg_count ASG(s); expected >=2"
  fail=$((fail + 1))
fi

if grep_tf '(source|destination)_application_security_group_ids'; then
  echo "  OK   At least one NSG rule references ASG via *_application_security_group_ids"
else
  echo "  FAIL No NSG rule references ASG via *_application_security_group_ids"
  fail=$((fail + 1))
fi

# ------------------------------------------------------------------
# 5. Storage + Key Vault locked down
# ------------------------------------------------------------------
check_tf_resource "azurerm_storage_account" 'resource[[:space:]]+"azurerm_storage_account"' || true
if grep_tf 'public_network_access_enabled[[:space:]]*=[[:space:]]*false'; then
  echo "  OK   Some resource has public_network_access_enabled = false"
else
  echo "  FAIL No resource has public_network_access_enabled = false"
  fail=$((fail + 1))
fi

check_tf_resource "azurerm_key_vault" 'resource[[:space:]]+"azurerm_key_vault"' || true

# ------------------------------------------------------------------
# 6. Private Endpoints + Private DNS Zones + VNet links
# ------------------------------------------------------------------
pe_count=$(grep -REc 'resource[[:space:]]+"azurerm_private_endpoint"' "$BASE"/*.tf 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ "$pe_count" -ge 2 ]; then
  echo "  OK   HCL has >=2 azurerm_private_endpoint ($pe_count found)"
else
  echo "  FAIL HCL has only $pe_count Private Endpoint(s); expected >=2 (blob + vault)"
  fail=$((fail + 1))
fi

if grep_tf 'subresource_names[[:space:]]*=[[:space:]]*\["blob"\]'; then
  echo "  OK   One Private Endpoint targets subresource \"blob\""
else
  echo "  FAIL No Private Endpoint targets subresource \"blob\""
  fail=$((fail + 1))
fi
if grep_tf 'subresource_names[[:space:]]*=[[:space:]]*\["vault"\]'; then
  echo "  OK   One Private Endpoint targets subresource \"vault\""
else
  echo "  FAIL No Private Endpoint targets subresource \"vault\""
  fail=$((fail + 1))
fi

if grep_tf 'privatelink\.blob\.core\.windows\.net'; then
  echo "  OK   Private DNS Zone 'privatelink.blob.core.windows.net' declared"
else
  echo "  FAIL Private DNS Zone 'privatelink.blob.core.windows.net' missing"
  fail=$((fail + 1))
fi
if grep_tf 'privatelink\.vaultcore\.azure\.net'; then
  echo "  OK   Private DNS Zone 'privatelink.vaultcore.azure.net' declared"
else
  echo "  FAIL Private DNS Zone 'privatelink.vaultcore.azure.net' missing"
  fail=$((fail + 1))
fi

link_count=$(grep -REc 'resource[[:space:]]+"azurerm_private_dns_zone_virtual_network_link"' "$BASE"/*.tf 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ "$link_count" -ge 2 ]; then
  echo "  OK   HCL has >=2 private_dns_zone_virtual_network_link ($link_count found)"
else
  echo "  FAIL HCL has only $link_count DNS zone VNet link(s); expected >=2"
  fail=$((fail + 1))
fi

# ------------------------------------------------------------------
# 7. No real tenant/subscription IDs
# ------------------------------------------------------------------
# Reject any hard-coded GUID that is NOT the placeholder all-zeros.
bad_guid=$(grep -REhoE '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' \
             "$BASE"/*.tf "$BASE"/*.md 2>/dev/null \
           | grep -vxE '0{8}-0{4}-0{4}-0{4}-0{12}' || true)
if [ -z "$bad_guid" ]; then
  echo "  OK   No real-looking tenant/subscription GUIDs in HCL or ADR"
else
  echo "  FAIL Found non-placeholder GUID(s) that may leak real IDs:"
  printf '       %s\n' $bad_guid
  fail=$((fail + 1))
fi

# ------------------------------------------------------------------
# 8. ADR structure
# ------------------------------------------------------------------
DOC="$BASE/ADR-VNET-DESIGN.md"
if [ -f "$DOC" ]; then
  if grep -qiE '^#+ *ADR' "$DOC"; then
    echo "  OK   ADR has an 'ADR' heading"
  else
    echo "  FAIL ADR missing an 'ADR' heading"
    fail=$((fail + 1))
  fi

  check_doc_section "$DOC" "Estado"        '^#+ *(Estado|Status)\b'
  check_doc_section "$DOC" "Contexto"      '^#+ *(Contexto|Context)\b'
  check_doc_section "$DOC" "Decisión"      '^#+ *(Decisi[oó]n|Decision)\b'
  check_doc_section "$DOC" "Consecuencias" '^#+ *(Consecuencias|Consequences)\b'
  check_doc_section "$DOC" "Alternativas"  '^#+ *(Alternativas|Alternatives)\b'

  fences=$(grep -cE '^```' "$DOC")
  if [ "$fences" -ge 2 ]; then
    echo "  OK   ADR has at least one fenced code block ($fences fence lines)"
  else
    echo "  FAIL ADR has only $fences code-fence line(s); expected >=2 (ASCII diagram)"
    fail=$((fail + 1))
  fi

  if grep -qiE 'westeurope|west europe|eu-west|eu-central|europe' "$DOC"; then
    echo "  OK   ADR mentions Europe / westeurope"
  else
    echo "  FAIL ADR does not mention Europe / westeurope"
    fail=$((fail + 1))
  fi

  for token in "Private +Endpoint" "Private +DNS +Zone" "NSG" "ASG"; do
    if grep -qiE "$token" "$DOC"; then
      echo "  OK   ADR mentions ${token}"
    else
      echo "  FAIL ADR does not mention ${token}"
      fail=$((fail + 1))
    fi
  done

  if grep -qE '10\.[0-9]{1,3}\.0\.0/1[0-9]' "$DOC"; then
    echo "  OK   ADR mentions a 10.X.0.0/1X CIDR plan"
  else
    echo "  FAIL ADR does not mention a 10.X.0.0/1X CIDR"
    fail=$((fail + 1))
  fi

  alt_count=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
  if [ "$alt_count" -ge 2 ]; then
    echo "  OK   ADR lists >=2 alternatives ($alt_count sub-headings)"
  else
    echo "  FAIL ADR lists only $alt_count alternative sub-heading(s) (expected >=2)"
    fail=$((fail + 1))
  fi
fi

# ------------------------------------------------------------------
# 9. Optional: terraform validate if available (does not count toward fail)
# ------------------------------------------------------------------
if command -v terraform >/dev/null 2>&1; then
  echo
  echo "-- Optional: terraform fmt -check (non-blocking) --"
  if terraform -chdir="$BASE" fmt -check -recursive >/dev/null 2>&1; then
    echo "  OK   terraform fmt -check passed"
  else
    echo "  WARN terraform fmt would reformat files (non-blocking)"
  fi
else
  echo
  echo "-- terraform not installed; skipping optional fmt check --"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness in a real Azure subscription is NOT verified here.)"
  exit 1
fi
echo "OK: estructura valida. Compara tu solucion con solution/ para autoevaluarte."
exit 0
