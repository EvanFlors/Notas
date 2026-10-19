#!/usr/bin/env bash
# Structural + light-semantic validation for
# aws-15-02-write-scp-baseline-and-validate.
#
# Checks that the 3 SCP JSON files exist, parse as JSON, carry the right
# Version/Statement/Effect, and include the minimum actions/conditions
# expected by the baseline. Also checks README-INTENT.md has one section
# per SCP.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real AWS account — compare
# manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-15-scp}"
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

# --- scp-deny-regions.json -----------------------------------------------
F1="$BASE/scp-deny-regions.json"
if check_file_exists "$F1"; then
  check_jq_valid "$F1" || true
  check_jq_contains "$F1" '.Version == "2012-10-17"' 'Version == "2012-10-17"'
  check_jq_contains "$F1" '[.Statement[].Effect] | any(. == "Deny")' 'at least one Statement with Effect=Deny'
  # NotAction present at top level of some statement
  check_jq_contains "$F1" '[.Statement[] | has("NotAction")] | any' 'uses NotAction (needed to exempt global services)'
  # Must include some global services in NotAction
  for action in "iam:" "organizations:" "cloudfront:" "route53:" "support:" "sts:"; do
    check_jq_contains "$F1" \
      "[.Statement[].NotAction // [] | if type == \"string\" then [.] else . end | .[]] | any(startswith(\"${action}\"))" \
      "NotAction mentions '${action}*'"
  done
  # Condition on aws:RequestedRegion
  check_jq_contains "$F1" \
    '[.Statement[].Condition // {} | .. | objects | has("aws:RequestedRegion")] | any' \
    'has Condition on aws:RequestedRegion'
  # Mentions at least one eu-* region
  check_jq_contains "$F1" \
    '[.Statement[].Condition // {} | .. | arrays | .[]? | select(type=="string")] | any(startswith("eu-"))' \
    'allows at least one eu-* region'
fi

# --- scp-deny-leave-org.json ---------------------------------------------
F2="$BASE/scp-deny-leave-org.json"
if check_file_exists "$F2"; then
  check_jq_valid "$F2" || true
  check_jq_contains "$F2" '.Version == "2012-10-17"' 'Version == "2012-10-17"'
  check_jq_contains "$F2" '[.Statement[].Effect] | any(. == "Deny")' 'at least one Statement with Effect=Deny'
  check_jq_contains "$F2" \
    '[.Statement[].Action // [] | if type=="string" then [.] else . end | .[]] | any(. == "organizations:LeaveOrganization")' \
    'denies organizations:LeaveOrganization'
fi

# --- scp-deny-disable-logging.json ---------------------------------------
F3="$BASE/scp-deny-disable-logging.json"
if check_file_exists "$F3"; then
  check_jq_valid "$F3" || true
  check_jq_contains "$F3" '.Version == "2012-10-17"' 'Version == "2012-10-17"'
  check_jq_contains "$F3" '[.Statement[].Effect] | any(. == "Deny")' 'at least one Statement with Effect=Deny'

  # Collect all Action strings across statements and count CloudTrail/Config ones.
  all_actions=$(jq -r '[.Statement[].Action // [] | if type=="string" then [.] else . end | .[]] | .[]' "$F3" 2>/dev/null || echo "")

  ct_count=0
  for a in "cloudtrail:StopLogging" "cloudtrail:DeleteTrail" "cloudtrail:UpdateTrail" "cloudtrail:PutEventSelectors" "cloudtrail:*"; do
    if printf '%s\n' "$all_actions" | grep -qx "$a"; then
      ct_count=$((ct_count+1))
    fi
  done
  if [ "$ct_count" -ge 3 ]; then
    echo "  OK   $F3: denies at least 3 CloudTrail destructive actions (${ct_count} matched)"
  else
    echo "  FAIL $F3: denies only ${ct_count} CloudTrail destructive actions (expected >=3)"
    fail=$((fail+1))
  fi

  cfg_count=0
  for a in "config:StopConfigurationRecorder" "config:DeleteConfigurationRecorder" "config:DeleteDeliveryChannel" "config:DeleteConfigRule" "config:*"; do
    if printf '%s\n' "$all_actions" | grep -qx "$a"; then
      cfg_count=$((cfg_count+1))
    fi
  done
  if [ "$cfg_count" -ge 2 ]; then
    echo "  OK   $F3: denies at least 2 Config destructive actions (${cfg_count} matched)"
  else
    echo "  FAIL $F3: denies only ${cfg_count} Config destructive actions (expected >=2)"
    fail=$((fail+1))
  fi
fi

# --- README-INTENT.md ----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  for section in "scp-deny-regions" "scp-deny-leave-org" "scp-deny-disable-logging"; do
    if grep -qE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section for ${section}"
    else
      echo "  FAIL README-INTENT.md missing section for ${section}"
      fail=$((fail+1))
    fi
  done
  # Must mention CloudTrail and Config in the intent doc.
  if grep -qi 'cloudtrail' "$DOC"; then
    echo "  OK   README-INTENT.md mentions CloudTrail"
  else
    echo "  FAIL README-INTENT.md does not mention CloudTrail"
    fail=$((fail+1))
  fi
  if grep -qiE '\bconfig\b|AWS +Config' "$DOC"; then
    echo "  OK   README-INTENT.md mentions AWS Config"
  else
    echo "  FAIL README-INTENT.md does not mention AWS Config"
    fail=$((fail+1))
  fi
  # Must justify NotAction / global services for deny-regions.
  if grep -qiE 'NotAction|globales?|global +service|iam:\\*' "$DOC"; then
    echo "  OK   README-INTENT.md justifies NotAction / global services"
  else
    echo "  FAIL README-INTENT.md does not justify NotAction / global services"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness in a real AWS account is NOT verified here.)"
  exit 1
fi
echo "OK: SCPs y README-INTENT.md pasan validacion estructural."
echo "    Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
