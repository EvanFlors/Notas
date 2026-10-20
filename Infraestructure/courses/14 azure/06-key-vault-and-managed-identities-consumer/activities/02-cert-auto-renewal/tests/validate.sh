#!/usr/bin/env bash
# Structural validation for az-06-02-cert-auto-renewal.
#
# Checks that certificate-policy.json + main.tf + README-INTENT.md exist
# and carry the minimum structure required by the brief: a valid Key Vault
# certificate policy JSON with AutoRenew + RSA >= 2048 + SAN, a Terraform
# azurerm_key_vault_certificate with the equivalent certificate_policy
# block, and a README-INTENT.md with the three required sections.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real Azure subscription — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/az-06-02}"
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

# --- certificate-policy.json ---------------------------------------------
F_JSON="$BASE/certificate-policy.json"
if check_file_exists "$F_JSON"; then
  if jq empty "$F_JSON" >/dev/null 2>&1; then
    echo "  OK   $F_JSON is valid JSON"
  else
    echo "  FAIL $F_JSON is not valid JSON"
    fail=$((fail+1))
  fi
  check_jq_contains "$F_JSON" '.issuerParameters | has("name")' 'issuerParameters.name present'
  check_jq_contains "$F_JSON" '.keyProperties.keyType == "RSA"' 'keyProperties.keyType == "RSA"'
  check_jq_contains "$F_JSON" '.keyProperties.keySize >= 2048' 'keyProperties.keySize >= 2048'
  check_jq_contains "$F_JSON" '(.lifetimeActions | type == "array") and (.lifetimeActions | length >= 1)' 'lifetimeActions is non-empty array'
  check_jq_contains "$F_JSON" '[.lifetimeActions[] | .action.actionType] | any(. == "AutoRenew")' 'at least one lifetimeAction with action.actionType == "AutoRenew"'
  check_jq_contains "$F_JSON" \
    '[.lifetimeActions[] | select(.action.actionType == "AutoRenew") | .trigger.daysBeforeExpiry] | any(type=="number" and . >= 1 and . <= 365)' \
    'AutoRenew trigger.daysBeforeExpiry is a number in [1,365]'
  check_jq_contains "$F_JSON" '.secretProperties | has("contentType")' 'secretProperties.contentType present'
  check_jq_contains "$F_JSON" '.x509CertificateProperties.subject | startswith("CN=")' 'subject starts with "CN="'
  check_jq_contains "$F_JSON" \
    '(.x509CertificateProperties.subjectAlternativeNames.dnsNames | type == "array") and (.x509CertificateProperties.subjectAlternativeNames.dnsNames | length >= 1)' \
    'subjectAlternativeNames.dnsNames is non-empty array'
  check_jq_contains "$F_JSON" '.x509CertificateProperties | has("validityInMonths")' 'validityInMonths present'
fi

# --- main.tf -------------------------------------------------------------
F_MAIN="$BASE/main.tf"
if check_file_exists "$F_MAIN"; then
  check_grep "$F_MAIN" 'provider +"azurerm"' 'declares azurerm provider'
  check_grep "$F_MAIN" 'resource +"azurerm_resource_group"' 'declares azurerm_resource_group'
  check_grep "$F_MAIN" 'resource +"azurerm_key_vault"' 'declares azurerm_key_vault'
  check_grep "$F_MAIN" 'resource +"azurerm_key_vault_certificate"' 'declares azurerm_key_vault_certificate'
  check_grep "$F_MAIN" 'certificate_policy +{' 'has certificate_policy block'
  check_grep "$F_MAIN" 'issuer_parameters +{' 'has issuer_parameters block'
  check_grep "$F_MAIN" 'key_properties +{' 'has key_properties block'
  check_grep "$F_MAIN" 'lifetime_action +{' 'has lifetime_action block'
  check_grep "$F_MAIN" 'action_type[[:space:]]*=[[:space:]]*"AutoRenew"' 'uses action_type = "AutoRenew"'
  check_grep "$F_MAIN" 'days_before_expiry[[:space:]]*=[[:space:]]*[0-9]+' 'uses numeric days_before_expiry'
  check_grep "$F_MAIN" 'x509_certificate_properties +{' 'has x509_certificate_properties block'
  check_grep "$F_MAIN" 'subject_alternative_names +{' 'has subject_alternative_names block'
fi

# --- README-INTENT.md ----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  for section in "certificate-policy" "auto-renewal" "issuer-strategy"; do
    if grep -qE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section for ${section}"
    else
      echo "  FAIL README-INTENT.md missing section for ${section}"
      fail=$((fail+1))
    fi
  done
  if grep -qiE 'AutoRenew|auto-renewal|auto renewal' "$DOC"; then
    echo "  OK   README-INTENT.md mentions AutoRenew / auto-renewal"
  else
    echo "  FAIL README-INTENT.md does not mention AutoRenew / auto-renewal"
    fail=$((fail+1))
  fi
  if grep -qiE 'DigiCert|GlobalSign' "$DOC"; then
    echo "  OK   README-INTENT.md names a real integrated issuer (DigiCert / GlobalSign)"
  else
    echo "  FAIL README-INTENT.md does not name an integrated issuer (expected DigiCert or GlobalSign)"
    fail=$((fail+1))
  fi
  if grep -qiE 'Managed +Identity' "$DOC"; then
    echo "  OK   README-INTENT.md mentions Managed Identity"
  else
    echo "  FAIL README-INTENT.md does not mention Managed Identity"
    fail=$((fail+1))
  fi
  if grep -qi 'certificate' "$DOC"; then
    echo "  OK   README-INTENT.md mentions 'certificate'"
  else
    echo "  FAIL README-INTENT.md does not mention 'certificate'"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s)."
  echo "        (Semantic correctness in a real Azure subscription is NOT verified here.)"
  exit 1
fi
echo "RESULT: 0 issue(s). Policy JSON, HCL y README-INTENT.md pasan validacion estructural."
echo "        Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
