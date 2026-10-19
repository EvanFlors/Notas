#!/usr/bin/env bash
# Structural + light-semantic validation for az-01-02-tagging-rg-vs-resource.
#
# Checks that tags-rg.json, tags-resource.json, tag-policy.json exist and are
# valid JSON, that they carry the required keys (RG: env/owner/cost-center/
# workload/managed-by; Resource: component/data-classification/backup-policy;
# Policy: policyType=Custom, policyRule.if, policyRule.then.effect in
# audit/append/modify/deny), and that README-INTENT.md has sections for
# each file plus Herencia / Inheritance.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness against a real Azure tenant — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/az-01-tagging}"
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

check_jq_valid() {
  local f="$1"
  if jq empty "$f" >/dev/null 2>&1; then
    echo "  OK   $f is valid JSON"
    return 0
  else
    echo "  FAIL $f is not valid JSON"
    fail=$((fail+1))
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
    fail=$((fail+1))
  fi
}

# --- tags-rg.json -------------------------------------------------------------
F1="$BASE/tags-rg.json"
if check_file_exists "$F1"; then
  check_jq_valid "$F1" || true
  for k in env owner cost-center workload managed-by; do
    check_jq_contains "$F1" "has(\"${k}\")" "has '${k}' tag"
  done
fi

# --- tags-resource.json -------------------------------------------------------
F2="$BASE/tags-resource.json"
if check_file_exists "$F2"; then
  check_jq_valid "$F2" || true
  for k in component data-classification backup-policy; do
    check_jq_contains "$F2" "has(\"${k}\")" "has '${k}' tag"
  done
fi

# --- tag-policy.json ----------------------------------------------------------
F3="$BASE/tag-policy.json"
if check_file_exists "$F3"; then
  check_jq_valid "$F3" || true
  # policyType == Custom (either wrapped under .properties or at root).
  check_jq_contains "$F3" \
    '(.properties.policyType // .policyType) == "Custom"' \
    'policyType == "Custom"'
  # mode present (Indexed or All).
  check_jq_contains "$F3" \
    '((.properties.mode // .mode) | . == "Indexed" or . == "All")' \
    'mode is Indexed or All'
  # policyRule.if exists.
  check_jq_contains "$F3" \
    '((.properties.policyRule // .policyRule) | has("if"))' \
    'has policyRule.if'
  # policyRule.then.effect is one of audit/append/modify/deny
  # (allow literal effect or ARM-style [parameters('effect')]).
  check_jq_contains "$F3" \
    '((.properties.policyRule // .policyRule).then.effect)
      | ( . == "audit" or . == "append" or . == "modify" or . == "deny"
          or (test("parameters\\(")) )' \
    'then.effect is audit/append/modify/deny (or [parameters()])'
  # Mentions the env tag somewhere in the rule.
  check_jq_contains "$F3" \
    '[.. | strings? | select(test("tags\\[.env.\\]|tags/env"))] | length > 0' \
    'rule references tags[env]'
fi

# --- README-INTENT.md ---------------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  for section in "tags-rg" "tags-resource" "tag-policy"; do
    if grep -qE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section for ${section}"
    else
      echo "  FAIL README-INTENT.md missing section for ${section}"
      fail=$((fail+1))
    fi
  done
  if grep -qiE '^#+ +(Herencia|Inheritance)' "$DOC"; then
    echo "  OK   README-INTENT.md has Herencia / Inheritance section"
  else
    echo "  FAIL README-INTENT.md missing Herencia / Inheritance section"
    fail=$((fail+1))
  fi
  # Must explain the no-inheritance-by-default + Policy modify|append story.
  if grep -qiE 'no +hereda|does +not +inherit|no +inheritance' "$DOC"; then
    echo "  OK   README-INTENT.md states that tags do NOT inherit by default"
  else
    echo "  FAIL README-INTENT.md does not state that tags do NOT inherit by default"
    fail=$((fail+1))
  fi
  if grep -qiE 'Azure +Policy' "$DOC" && grep -qiE 'modify|append' "$DOC"; then
    echo "  OK   README-INTENT.md mentions Azure Policy modify/append"
  else
    echo "  FAIL README-INTENT.md does not mention Azure Policy modify/append"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness in a real Azure tenant is NOT verified here.)"
  exit 1
fi
echo "OK: tags y Azure Policy sketch pasan validacion estructural."
echo "    Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
