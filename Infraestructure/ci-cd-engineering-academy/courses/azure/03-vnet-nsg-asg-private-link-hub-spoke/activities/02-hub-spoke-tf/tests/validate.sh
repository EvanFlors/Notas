#!/usr/bin/env bash
# Structural validation for az-03-02-hub-spoke-tf.
# Checks that the 5 Terraform files + TOPOLOGY.md exist in the student's
# working directory and contain the expected hub-spoke resources, peerings,
# subnets and DNS zone links.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real Azure subscription — compare
# with solution/ afterwards.

set -eu

BASE="${1:-/tmp/az-03-02-hub-spoke}"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist."
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

grep_tf() {
  local pat="$1"
  grep -RqE "$pat" "$BASE"/*.tf 2>/dev/null && return 0 || return 1
}

count_tf() {
  grep -REc "$1" "$BASE"/*.tf 2>/dev/null | awk -F: '{s+=$2} END{print s+0}'
}

# ------------------------------------------------------------------
# 1. Required files
# ------------------------------------------------------------------
check_file_exists "$BASE/providers.tf" || true
check_file_exists "$BASE/hub.tf"       || true
check_file_exists "$BASE/spoke-a.tf"   || true
check_file_exists "$BASE/spoke-b.tf"   || true
check_file_exists "$BASE/peering.tf"   || true
check_file_exists "$BASE/TOPOLOGY.md"  || true

if ! ls "$BASE"/*.tf >/dev/null 2>&1; then
  echo
  echo "RESULT: $fail check(s) failed (no .tf files found)."
  exit 1
fi

# ------------------------------------------------------------------
# 2. Provider
# ------------------------------------------------------------------
if grep_tf 'required_providers' && grep_tf 'provider[[:space:]]+"azurerm"'; then
  echo "  OK   azurerm provider declared with required_providers + provider block"
else
  echo "  FAIL azurerm provider not fully declared (need required_providers + provider block)"
  fail=$((fail + 1))
fi

# ------------------------------------------------------------------
# 3. Three VNets with distinct, non-overlapping CIDRs
# ------------------------------------------------------------------
vnet_count=$(count_tf 'resource[[:space:]]+"azurerm_virtual_network"')
if [ "$vnet_count" -ge 3 ]; then
  echo "  OK   >=3 azurerm_virtual_network resources ($vnet_count found)"
else
  echo "  FAIL only $vnet_count azurerm_virtual_network; expected 3 (hub + 2 spokes)"
  fail=$((fail + 1))
fi

# Collect address_space CIDRs
cidrs=$(grep -REh 'address_space[[:space:]]*=' "$BASE"/*.tf 2>/dev/null \
          | grep -oE '"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+"' \
          | tr -d '"' | sort -u)
cidr_count=$(printf '%s\n' "$cidrs" | grep -c '/' || true)
if [ "$cidr_count" -ge 3 ]; then
  echo "  OK   >=3 distinct address_space CIDRs ($cidr_count): $(echo $cidrs | tr '\n' ' ')"
else
  echo "  FAIL only $cidr_count distinct address_space CIDRs; expected >=3"
  fail=$((fail + 1))
fi

# ------------------------------------------------------------------
# 4. Hub special subnets (literal names required by Azure)
# ------------------------------------------------------------------
for sn in "AzureFirewallSubnet" "GatewaySubnet"; do
  if grep_tf "name[[:space:]]*=[[:space:]]*\"${sn}\""; then
    echo "  OK   subnet '${sn}' present"
  else
    echo "  FAIL subnet '${sn}' missing in hub (literal name required by Azure)"
    fail=$((fail + 1))
  fi
done

# ------------------------------------------------------------------
# 5. 4 peerings, correct orientation
# ------------------------------------------------------------------
peer_count=$(count_tf 'resource[[:space:]]+"azurerm_virtual_network_peering"')
if [ "$peer_count" -ge 4 ]; then
  echo "  OK   >=4 azurerm_virtual_network_peering resources ($peer_count found)"
else
  echo "  FAIL only $peer_count peering resource(s); expected 4 (bidirectional for both spokes)"
  fail=$((fail + 1))
fi

# At least one peering with allow_forwarded_traffic = true
if grep_tf 'allow_forwarded_traffic[[:space:]]*=[[:space:]]*true'; then
  echo "  OK   At least one peering has allow_forwarded_traffic = true"
else
  echo "  FAIL No peering has allow_forwarded_traffic = true"
  fail=$((fail + 1))
fi
# At least one peering with allow_gateway_transit = true
if grep_tf 'allow_gateway_transit[[:space:]]*=[[:space:]]*true'; then
  echo "  OK   At least one peering has allow_gateway_transit = true"
else
  echo "  FAIL No peering has allow_gateway_transit = true"
  fail=$((fail + 1))
fi

# Must NOT contain a peering between spoke-a and spoke-b directly
if grep -REqi 'spoke[-_]?a[-_]?to[-_]?spoke[-_]?b|spoke[-_]?b[-_]?to[-_]?spoke[-_]?a' "$BASE"/*.tf 2>/dev/null; then
  echo "  FAIL Found a peering named spoke-a <-> spoke-b (patron Hub-Spoke no permite peering directo entre spokes)"
  fail=$((fail + 1))
else
  echo "  OK   No direct spoke-a <-> spoke-b peering (non-transitividad respetada)"
fi

# ------------------------------------------------------------------
# 6. Private DNS Zone + >=3 VNet links
# ------------------------------------------------------------------
if grep_tf 'resource[[:space:]]+"azurerm_private_dns_zone"[[:space:]]'; then
  echo "  OK   At least one azurerm_private_dns_zone declared"
else
  echo "  FAIL No azurerm_private_dns_zone declared"
  fail=$((fail + 1))
fi

if grep_tf 'privatelink\.'; then
  echo "  OK   DNS zone name starts with 'privatelink.'"
else
  echo "  FAIL No DNS zone name starts with 'privatelink.'"
  fail=$((fail + 1))
fi

link_count=$(count_tf 'resource[[:space:]]+"azurerm_private_dns_zone_virtual_network_link"')
if [ "$link_count" -ge 3 ]; then
  echo "  OK   >=3 private_dns_zone_virtual_network_link ($link_count found: hub + 2 spokes)"
else
  echo "  FAIL only $link_count DNS link(s); expected >=3 (hub + spoke-a + spoke-b)"
  fail=$((fail + 1))
fi

# ------------------------------------------------------------------
# 7. No real GUIDs
# ------------------------------------------------------------------
bad_guid=$(grep -REhoE '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' \
             "$BASE"/*.tf "$BASE"/*.md 2>/dev/null \
           | grep -vxE '0{8}-0{4}-0{4}-0{4}-0{12}' || true)
if [ -z "$bad_guid" ]; then
  echo "  OK   No real-looking tenant/subscription GUIDs in HCL or TOPOLOGY.md"
else
  echo "  FAIL Found non-placeholder GUID(s):"
  printf '       %s\n' $bad_guid
  fail=$((fail + 1))
fi

# ------------------------------------------------------------------
# 8. TOPOLOGY.md content
# ------------------------------------------------------------------
DOC="$BASE/TOPOLOGY.md"
if [ -f "$DOC" ]; then
  fences=$(grep -cE '^```' "$DOC")
  if [ "$fences" -ge 2 ]; then
    echo "  OK   TOPOLOGY.md has at least one fenced block ($fences fence lines)"
  else
    echo "  FAIL TOPOLOGY.md has only $fences code-fence line(s); expected >=2 (ASCII diagram)"
    fail=$((fail + 1))
  fi

  for token in "hub" "spoke" "peering" "non.?transit" "Firewall"; do
    if grep -qiE "$token" "$DOC"; then
      echo "  OK   TOPOLOGY.md mentions ${token}"
    else
      echo "  FAIL TOPOLOGY.md does not mention ${token}"
      fail=$((fail + 1))
    fi
  done

  for token in "allow_forwarded_traffic" "allow_gateway_transit"; do
    if grep -q "$token" "$DOC"; then
      echo "  OK   TOPOLOGY.md mentions ${token}"
    else
      echo "  FAIL TOPOLOGY.md does not mention ${token}"
      fail=$((fail + 1))
    fi
  done

  if grep -qE '10\.[0-9]{1,3}\.0\.0/[0-9]{1,2}' "$DOC"; then
    echo "  OK   TOPOLOGY.md mentions a 10.X.0.0/XX CIDR plan"
  else
    echo "  FAIL TOPOLOGY.md does not mention a 10.X.0.0/XX CIDR"
    fail=$((fail + 1))
  fi
fi

# ------------------------------------------------------------------
# 9. Optional: terraform fmt check if terraform is installed
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
echo "OK: estructura valida. Compara con solution/ para autoevaluarte."
exit 0
