#!/usr/bin/env bash
# Structural + light-semantic validation for
# az-09-02-write-azure-policy-baseline-and-validate.
#
# Checks that the 3 Azure policyDefinition JSON files exist, parse as JSON,
# carry the required properties.mode, properties.policyRule.if/then.effect,
# and include the minimum fields/conditions expected by the baseline. Also
# checks README-INTENT.md has one section per policy plus the Log Analytics
# mention and the 'global' location justification.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real Azure tenant — compare
# manually with solution/*.json and solution/README-INTENT.md.

set -eu

BASE="${1:-/tmp/az-09-policy}"
issues=0

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
    issues=$((issues+1))
    return 1
  fi
}

check_jq_valid() {
  local f="$1"
  if jq empty "$f" >/dev/null 2>&1; then
    echo "  OK   $f is valid JSON"
    return 0
  else
    echo "  FAIL $f is not valid JSON"
    issues=$((issues+1))
    return 1
  fi
}

check_jq_contains() {
  local f="$1"
  local expr="$2"
  local label="$3"
  local val
  val=$(jq -r "$expr" "$f" 2>/dev/null || echo "")
  if [ "$val" = "true" ]; then
    echo "  OK   $f: ${label}"
  else
    echo "  FAIL $f: ${label} (expr: $expr)"
    issues=$((issues+1))
  fi
}

# --- policy-deny-locations.json ------------------------------------------
F1="$BASE/policy-deny-locations.json"
if check_file_exists "$F1"; then
  check_jq_valid "$F1" || true
  check_jq_contains "$F1" '.properties != null' 'has top-level .properties object'
  check_jq_contains "$F1" '.properties.policyType == "Custom"' 'policyType == "Custom"'
  check_jq_contains "$F1" '(.properties.mode == "All") or (.properties.mode == "Indexed")' 'mode is "All" or "Indexed"'
  check_jq_contains "$F1" '.properties.parameters.allowedLocations != null' 'parameters.allowedLocations exists'
  check_jq_contains "$F1" '.properties.parameters.allowedLocations.type == "Array"' 'parameters.allowedLocations.type == "Array"'
  check_jq_contains "$F1" \
    '[.properties.parameters.allowedLocations.defaultValue // [] | .[]] | any(startswith("eu-") or startswith("westeurope") or startswith("northeurope") or startswith("francecentral") or startswith("germanywestcentral") or startswith("swedencentral"))' \
    'defaultValue lists at least one European region'
  check_jq_contains "$F1" '.properties.policyRule.then.effect == "deny"' 'policyRule.then.effect == "deny"'
  # Must reference parameters('allowedLocations') somewhere in the rule
  if jq -r '.properties.policyRule' "$F1" | grep -q "parameters('allowedLocations')"; then
    echo "  OK   $F1: policyRule references parameters('allowedLocations')"
  else
    echo "  FAIL $F1: policyRule does not reference parameters('allowedLocations')"
    issues=$((issues+1))
  fi
  # Must exempt location "global"
  if jq -r '.properties.policyRule' "$F1" | grep -q '"global"'; then
    echo "  OK   $F1: exempts location 'global'"
  else
    echo "  FAIL $F1: does not exempt location 'global' (needed for Front Door, DNS zones, role definitions)"
    issues=$((issues+1))
  fi
  # Must use field: location
  check_jq_contains "$F1" \
    '[.properties.policyRule | .. | objects | select(has("field")) | .field] | any(. == "location")' \
    'uses field: "location" in policyRule'
fi

# --- policy-deny-public-ip.json ------------------------------------------
F2="$BASE/policy-deny-public-ip.json"
if check_file_exists "$F2"; then
  check_jq_valid "$F2" || true
  check_jq_contains "$F2" '.properties != null' 'has top-level .properties object'
  check_jq_contains "$F2" '.properties.policyType == "Custom"' 'policyType == "Custom"'
  check_jq_contains "$F2" '(.properties.mode == "All") or (.properties.mode == "Indexed")' 'mode is "All" or "Indexed"'
  check_jq_contains "$F2" '.properties.policyRule.then.effect == "deny"' 'policyRule.then.effect == "deny"'
  check_jq_contains "$F2" \
    '[.properties.policyRule | .. | objects | select(has("field") and has("equals")) | select(.field == "type") | .equals] | any(. == "Microsoft.Network/publicIPAddresses")' \
    'policyRule checks type == "Microsoft.Network/publicIPAddresses"'
fi

# --- policy-audit-diagnostic-settings.json -------------------------------
F3="$BASE/policy-audit-diagnostic-settings.json"
if check_file_exists "$F3"; then
  check_jq_valid "$F3" || true
  check_jq_contains "$F3" '.properties != null' 'has top-level .properties object'
  check_jq_contains "$F3" '.properties.policyType == "Custom"' 'policyType == "Custom"'
  check_jq_contains "$F3" '(.properties.mode == "All") or (.properties.mode == "Indexed")' 'mode is "All" or "Indexed"'
  check_jq_contains "$F3" '.properties.policyRule.then.effect == "auditIfNotExists"' 'policyRule.then.effect == "auditIfNotExists"'
  check_jq_contains "$F3" '.properties.policyRule.then.details.type == "Microsoft.Insights/diagnosticSettings"' 'details.type == "Microsoft.Insights/diagnosticSettings"'
  # Must check at least one concrete field: type (resource type under audit)
  check_jq_contains "$F3" \
    '[.properties.policyRule | .. | objects | select(has("field") and has("equals")) | select(.field == "type") | .equals] | any(startswith("Microsoft."))' \
    'policyRule checks a concrete Microsoft.* resource type'
  # Must mention logs.enabled or workspaceId in existenceCondition
  if jq -r '.properties.policyRule.then.details.existenceCondition // {}' "$F3" | grep -qE 'logs\.enabled|workspaceId'; then
    echo "  OK   $F3: existenceCondition checks logs.enabled or workspaceId"
  else
    echo "  FAIL $F3: existenceCondition does not check logs.enabled or workspaceId"
    issues=$((issues+1))
  fi
fi

# --- README-INTENT.md ----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  for section in "policy-deny-locations" "policy-deny-public-ip" "policy-audit-diagnostic-settings"; do
    if grep -qE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section for ${section}"
    else
      echo "  FAIL README-INTENT.md missing section for ${section}"
      issues=$((issues+1))
    fi
  done
  # Must mention Log Analytics in the intent doc.
  if grep -qiE 'log +analytics|logAnalytics|Microsoft\.OperationalInsights' "$DOC"; then
    echo "  OK   README-INTENT.md mentions Log Analytics"
  else
    echo "  FAIL README-INTENT.md does not mention Log Analytics"
    issues=$((issues+1))
  fi
  # Must mention diagnostic settings
  if grep -qiE 'diagnostic +settings?|diagnosticSettings' "$DOC"; then
    echo "  OK   README-INTENT.md mentions diagnostic settings"
  else
    echo "  FAIL README-INTENT.md does not mention diagnostic settings"
    issues=$((issues+1))
  fi
  # Must justify why 'global' location is exempted.
  if grep -qiE '"?global"?.*(Front +Door|DNS|Traffic +Manager|role +definit|globales?)|globales?.*(Front +Door|DNS|Traffic +Manager)|exceptu[ae].*global|global.*except' "$DOC"; then
    echo "  OK   README-INTENT.md justifies the 'global' location exception"
  else
    echo "  FAIL README-INTENT.md does not justify the 'global' location exception"
    issues=$((issues+1))
  fi
  # Must mention Management Group / MG as scope of assignment
  if grep -qiE 'Management +Group|\bMG\b|MGs' "$DOC"; then
    echo "  OK   README-INTENT.md mentions Management Group as assignment scope"
  else
    echo "  FAIL README-INTENT.md does not mention Management Group as assignment scope"
    issues=$((issues+1))
  fi
fi

echo
if [ "$issues" -gt 0 ]; then
  echo "RESULT: $issues issue(s) found."
  echo "        (Semantic correctness in a real Azure tenant is NOT verified here.)"
  exit 1
fi
echo "RESULT: 0 issue(s). Policies y README-INTENT.md pasan validacion estructural."
echo "Compara con solution/ para autoevaluacion semantica."
exit 0
