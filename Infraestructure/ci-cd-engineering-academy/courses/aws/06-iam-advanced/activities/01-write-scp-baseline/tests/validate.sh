#!/usr/bin/env bash
# Structural validation for aws-06-01-write-scp-baseline.
# Checks that the three SCP JSON files exist, are valid JSON, follow IAM
# policy structure (Version/Statement/Effect/Action|NotAction/Resource),
# and contain the markers that each SCP must have (region condition,
# cloudtrail/config actions, MFA condition). Also checks BASELINE.md for
# the four required sections.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `jq ... | grep -q ...` which can produce SIGPIPE (exit 141) when
# grep finds a match early. pipefail would spuriously mark those as
# failures.
#
# Does NOT grade semantic correctness — compare with solution/REFERENCE.md
# and solution/policies/.

set -eu

BASE="${1:-/tmp/aws-06-scp-baseline}"
DOC="$BASE/BASELINE.md"
POLDIR="$BASE/policies"
P1="$POLDIR/01-deny-regions.json"
P2="$POLDIR/02-deny-audit-tamper.json"
P3="$POLDIR/03-require-mfa-destructive.json"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq is required. Install with: brew install jq / apt-get install jq"
  exit 2
fi

# --- Files exist ---
for f in "$DOC" "$P1" "$P2" "$P3"; do
  if [ ! -f "$f" ]; then
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
  else
    echo "  OK   $f exists"
  fi
done
if [ "$fail" -gt 0 ]; then
  echo
  echo "RESULT: $fail missing file(s). Produce them first."
  exit 1
fi

# --- Helper: structural checks for a single policy ---
check_policy_structure() {
  local f="$1"
  local label="$2"

  if ! jq -e . "$f" >/dev/null 2>&1; then
    echo "  FAIL [$label] not valid JSON"
    fail=$((fail+1))
    return
  fi
  echo "  OK   [$label] valid JSON"

  if jq -e '.Version == "2012-10-17"' "$f" >/dev/null 2>&1; then
    echo "  OK   [$label] Version is 2012-10-17"
  else
    echo "  FAIL [$label] Version must be \"2012-10-17\""
    fail=$((fail+1))
  fi

  if jq -e '.Statement | type == "array" and length >= 1' "$f" >/dev/null 2>&1; then
    echo "  OK   [$label] Statement is non-empty array"
  else
    echo "  FAIL [$label] Statement must be a non-empty array"
    fail=$((fail+1))
  fi

  if jq -e '[.Statement[] | .Effect] | all(. == "Allow" or . == "Deny")' "$f" >/dev/null 2>&1; then
    echo "  OK   [$label] every Statement has valid Effect"
  else
    echo "  FAIL [$label] every Statement must have Effect in {Allow,Deny}"
    fail=$((fail+1))
  fi

  if jq -e '[.Statement[] | .Effect] | any(. == "Deny")' "$f" >/dev/null 2>&1; then
    echo "  OK   [$label] has at least one Deny statement"
  else
    echo "  FAIL [$label] SCP baseline must have at least one Deny statement"
    fail=$((fail+1))
  fi

  if jq -e '.Statement | map(select((.Action // .NotAction) != null)) | length == (. | length)' "$f" >/dev/null 2>&1; then
    echo "  OK   [$label] every Statement has Action or NotAction"
  else
    echo "  FAIL [$label] every Statement must have Action or NotAction"
    fail=$((fail+1))
  fi

  if jq -e '.Statement | map(select((.Resource // .NotResource) != null)) | length == (. | length)' "$f" >/dev/null 2>&1; then
    echo "  OK   [$label] every Statement has Resource or NotResource"
  else
    echo "  FAIL [$label] every Statement must have Resource or NotResource"
    fail=$((fail+1))
  fi
}

# --- Per-policy content ---

echo
echo "== Policy 01 (deny-regions) =="
check_policy_structure "$P1" "01"

# Must use NotAction (to exclude global services) and aws:RequestedRegion.
if jq -e '[.Statement[] | select(.NotAction != null)] | length >= 1' "$P1" >/dev/null 2>&1; then
  echo "  OK   [01] uses NotAction (to exclude global services)"
else
  echo "  FAIL [01] expected NotAction to exclude global services"
  fail=$((fail+1))
fi

if grep -q 'aws:RequestedRegion' "$P1"; then
  echo "  OK   [01] mentions aws:RequestedRegion"
else
  echo "  FAIL [01] must condition on aws:RequestedRegion"
  fail=$((fail+1))
fi

for svc in "iam:" "sts:"; do
  if grep -q "\"$svc" "$P1"; then
    echo "  OK   [01] excludes global service $svc"
  else
    echo "  FAIL [01] expected global service $svc inside NotAction"
    fail=$((fail+1))
  fi
done

echo
echo "== Policy 02 (deny-audit-tamper) =="
check_policy_structure "$P2" "02"

for action in "cloudtrail:" "config:"; do
  if grep -q "\"$action" "$P2"; then
    echo "  OK   [02] mentions $action actions"
  else
    echo "  FAIL [02] expected $action actions"
    fail=$((fail+1))
  fi
done

if grep -qE 'cloudtrail:StopLogging|cloudtrail:DeleteTrail' "$P2"; then
  echo "  OK   [02] denies at least one destructive CloudTrail action"
else
  echo "  FAIL [02] must deny cloudtrail:StopLogging or cloudtrail:DeleteTrail"
  fail=$((fail+1))
fi

if grep -qE 'config:DeleteConfigurationRecorder|config:StopConfigurationRecorder' "$P2"; then
  echo "  OK   [02] denies at least one destructive Config action"
else
  echo "  FAIL [02] must deny config:DeleteConfigurationRecorder or StopConfigurationRecorder"
  fail=$((fail+1))
fi

echo
echo "== Policy 03 (require-mfa-destructive) =="
check_policy_structure "$P3" "03"

if grep -q 'aws:MultiFactorAuthPresent' "$P3"; then
  echo "  OK   [03] conditions on aws:MultiFactorAuthPresent"
else
  echo "  FAIL [03] must condition on aws:MultiFactorAuthPresent"
  fail=$((fail+1))
fi

# BoolIfExists is strongly preferred — accept Bool as fallback but warn.
if grep -q 'BoolIfExists' "$P3"; then
  echo "  OK   [03] uses BoolIfExists (robust)"
elif grep -q '"Bool"' "$P3"; then
  echo "  WARN [03] uses Bool instead of BoolIfExists — document the choice in BASELINE.md"
else
  echo "  FAIL [03] must use Bool or BoolIfExists operator"
  fail=$((fail+1))
fi

if grep -qE 's3:Delete|iam:Delete' "$P3"; then
  echo "  OK   [03] denies at least one destructive S3 or IAM Delete action"
else
  echo "  FAIL [03] must deny at least one s3:Delete* or iam:Delete* action"
  fail=$((fail+1))
fi

# --- BASELINE.md sections ---

echo
echo "== BASELINE.md sections =="

for section in "A" "B" "C" "D"; do
  if grep -qiE "^#+ *(Secci[óo]n +$section\b|$section\. )" "$DOC"; then
    echo "  OK   BASELINE.md has Section $section"
  else
    echo "  FAIL BASELINE.md missing Section $section"
    fail=$((fail+1))
  fi
done

# Must mention the three key concepts somewhere in the document.
for term in "SCP" "MFA" "CloudTrail"; do
  if grep -qi "$term" "$DOC"; then
    echo "  OK   BASELINE.md mentions $term"
  else
    echo "  FAIL BASELINE.md must mention $term"
    fail=$((fail+1))
  fi
done

# Must answer: can admin bypass? → should mention "Deny" + "always wins" or similar.
if grep -qiE 'deny.*gana|deny.*wins|no se puede|no puede saltar|no se compensa' "$DOC"; then
  echo "  OK   BASELINE.md explains why an identity Allow cannot bypass an SCP Deny"
else
  echo "  FAIL BASELINE.md must explain why identity Allow does not bypass SCP Deny"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara BASELINE.md y las policies con solution/ para autoevaluarte."
exit 0
