#!/usr/bin/env bash
# Structural + light-semantic validation for
# az-02-01-least-privilege-storage-reader.
#
# Checks that the 2 custom role JSON files exist, parse as JSON, carry
# the required top-level keys, encode the right (and ONLY the right)
# DataAction, and avoid obvious over-privileged tokens. Also checks that
# README-INTENT.md has one section per role plus the scope decision and
# the DataActions / Managed Identity mentions.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many
# checks use `... | grep -q ...` which can produce SIGPIPE (exit 141)
# when grep finds a match early. pipefail would spuriously mark those
# as failures.
#
# Does NOT grade semantic correctness in a real Azure tenant — compare
# manually with solution/*.json and solution/README-INTENT.md.

set -eu

BASE="${1:-/tmp/az-02-role}"
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

check_jq_true() {
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

validate_base_role() {
  local f="$1"
  check_jq_valid "$f" || return 0

  # Required top-level keys.
  for key in Name Description Actions NotActions DataActions NotDataActions AssignableScopes; do
    check_jq_true "$f" "has(\"$key\")" "top-level key '$key' is present"
  done

  # Name / Description are non-empty strings.
  check_jq_true "$f" '(.Name|type=="string") and (.Name|length > 0)' 'Name is a non-empty string'
  check_jq_true "$f" '(.Description|type=="string") and (.Description|length > 0)' 'Description is a non-empty string'

  # Actions must be an empty array (least privilege: no management-plane).
  check_jq_true "$f" '(.Actions|type=="array") and (.Actions|length == 0)' 'Actions is an empty array (no management-plane ops)'

  # NotActions and NotDataActions arrays and empty.
  check_jq_true "$f" '(.NotActions|type=="array") and (.NotActions|length == 0)' 'NotActions is empty'
  check_jq_true "$f" '(.NotDataActions|type=="array") and (.NotDataActions|length == 0)' 'NotDataActions is empty'

  # DataActions contains exactly the blob read, and no write/delete token.
  check_jq_true "$f" \
    '(.DataActions|type=="array") and (.DataActions | index("Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read") != null)' \
    'DataActions contains the blob read action'
  check_jq_true "$f" \
    '[.DataActions[]? | ascii_downcase] | all(contains("write") | not) and all(contains("delete") | not) and all(. != "*")' \
    'DataActions does not contain write/delete/* tokens'

  # No listKeys / regenerateKey / role write escalation anywhere.
  check_jq_true "$f" \
    '[.. | strings] | all(contains("listKeys") | not)' \
    'no listKeys anywhere in the document'
  check_jq_true "$f" \
    '[.. | strings] | all(contains("regenerateKey") | not)' \
    'no regenerateKey anywhere in the document'
  check_jq_true "$f" \
    '[.. | strings] | all(contains("Microsoft.Authorization/roleAssignments/write") | not)' \
    'no role-assignment write anywhere (no privilege escalation)'

  # AssignableScopes: array with at least one /subscriptions/<...> string.
  check_jq_true "$f" \
    '(.AssignableScopes|type=="array") and (.AssignableScopes|length >= 1)' \
    'AssignableScopes is a non-empty array'
  check_jq_true "$f" \
    '[.AssignableScopes[]] | all(type=="string" and startswith("/subscriptions/"))' \
    'every AssignableScope starts with /subscriptions/'

  # Must NOT include a real-looking UUID in AssignableScopes (encourage placeholders).
  check_jq_true "$f" \
    '[.AssignableScopes[]] | all(test("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}") | not)' \
    'no real-looking UUID in AssignableScopes (use <SUB-UUID-PLACEHOLDER>)'
}

# --- role-storage-blob-reader.json ---------------------------------------
F1="$BASE/role-storage-blob-reader.json"
if check_file_exists "$F1"; then
  validate_base_role "$F1"
fi

# --- role-storage-blob-reader-with-condition.json ------------------------
F2="$BASE/role-storage-blob-reader-with-condition.json"
if check_file_exists "$F2"; then
  validate_base_role "$F2"
  # Condition presence (either top-level or inside DataActions objects).
  check_jq_true "$F2" \
    '([.. | objects | keys[]?] | map(ascii_downcase) | any(. == "condition"))' \
    'has a Condition / condition key somewhere'
  check_jq_true "$F2" \
    '([.. | objects | to_entries[]? | select((.key|ascii_downcase)=="conditionversion") | .value] | any(. == "2.0"))' \
    'ConditionVersion is "2.0"'
  check_jq_true "$F2" \
    '[.. | strings] | any(contains("StringEquals") or contains("StringStartsWith"))' \
    'condition expression uses StringEquals or StringStartsWith'
  check_jq_true "$F2" \
    '[.. | strings] | any(contains("blobs") or contains("path"))' \
    'condition expression mentions blobs or path'
fi

# --- README-INTENT.md ----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  for section in "role-storage-blob-reader" "role-storage-blob-reader-with-condition" "Decisi[oó]n de scope"; do
    if grep -qiE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section matching '${section}'"
    else
      echo "  FAIL README-INTENT.md missing section matching '${section}'"
      issues=$((issues+1))
    fi
  done
  if grep -q 'DataActions' "$DOC"; then
    echo "  OK   README-INTENT.md mentions DataActions"
  else
    echo "  FAIL README-INTENT.md does not mention DataActions"
    issues=$((issues+1))
  fi
  if grep -qiE 'managed +identity|managed-identity' "$DOC"; then
    echo "  OK   README-INTENT.md mentions Managed Identity"
  else
    echo "  FAIL README-INTENT.md does not mention Managed Identity"
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
echo "        Compare with solution/*.json and solution/README-INTENT.md for self-assessment."
exit 0
