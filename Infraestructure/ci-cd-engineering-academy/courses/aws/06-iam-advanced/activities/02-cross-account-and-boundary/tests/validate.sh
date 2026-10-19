#!/usr/bin/env bash
# Structural validation for aws-06-02-cross-account-and-boundary.
# Checks four JSON policies and a DECISIONS.md with five sections.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many
# checks use `jq ... | grep -q ...` which can produce SIGPIPE (exit 141)
# when grep finds a match early. pipefail would spuriously mark those
# as failures.
#
# Does NOT grade semantic correctness — compare with solution/REFERENCE.md
# and solution/policies/.

set -eu

BASE="${1:-/tmp/aws-06-cross-account}"
DOC="$BASE/DECISIONS.md"
POLDIR="$BASE/policies"
P_BOUND="$POLDIR/boundary-dev.json"
P_DEVID="$POLDIR/developer-identity.json"
P_TRUSTO="$POLDIR/trust-intra-org.json"
P_TRUSTV="$POLDIR/trust-vendor-external.json"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq is required."
  exit 2
fi

for f in "$DOC" "$P_BOUND" "$P_DEVID" "$P_TRUSTO" "$P_TRUSTV"; do
  if [ ! -f "$f" ]; then
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
  else
    echo "  OK   $f exists"
  fi
done
if [ "$fail" -gt 0 ]; then
  echo
  echo "RESULT: $fail missing file(s)."
  exit 1
fi

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
    echo "  OK   [$label] Statement non-empty array"
  else
    echo "  FAIL [$label] Statement must be non-empty array"
    fail=$((fail+1))
  fi

  if jq -e '[.Statement[] | .Effect] | all(. == "Allow" or . == "Deny")' "$f" >/dev/null 2>&1; then
    echo "  OK   [$label] every Statement has valid Effect"
  else
    echo "  FAIL [$label] every Statement must have valid Effect"
    fail=$((fail+1))
  fi
}

echo
echo "== Boundary for developers =="
check_policy_structure "$P_BOUND" "boundary"

if jq -e '[.Statement[] | .Effect] | any(. == "Allow")' "$P_BOUND" >/dev/null 2>&1 && \
   jq -e '[.Statement[] | .Effect] | any(. == "Deny")' "$P_BOUND" >/dev/null 2>&1; then
  echo "  OK   [boundary] has both Allow and Deny statements"
else
  echo "  FAIL [boundary] must have both Allow (runtime perms) and Deny (anti-escalation)"
  fail=$((fail+1))
fi

if grep -qE 'iam:DeleteRolePermissionsBoundary|iam:DeleteUserPermissionsBoundary' "$P_BOUND"; then
  echo "  OK   [boundary] denies removing own permissions boundary"
else
  echo "  FAIL [boundary] MUST deny iam:DeleteRolePermissionsBoundary or iam:DeleteUserPermissionsBoundary"
  fail=$((fail+1))
fi

if grep -qE 'iam:CreateUser|iam:AttachUserPolicy|iam:CreateAccessKey' "$P_BOUND"; then
  echo "  OK   [boundary] denies at least one classic escalation action"
else
  echo "  FAIL [boundary] must deny at least one of iam:CreateUser / AttachUserPolicy / CreateAccessKey"
  fail=$((fail+1))
fi

echo
echo "== Developer identity policy =="
check_policy_structure "$P_DEVID" "devid"

if grep -q 'iam:PermissionsBoundary' "$P_DEVID"; then
  echo "  OK   [devid] uses iam:PermissionsBoundary condition"
else
  echo "  FAIL [devid] MUST use iam:PermissionsBoundary condition to force boundary attachment"
  fail=$((fail+1))
fi

if grep -qE 'iam:CreateRole|iam:AttachRolePolicy' "$P_DEVID"; then
  echo "  OK   [devid] allows role creation / policy attachment"
else
  echo "  FAIL [devid] must allow at least iam:CreateRole or iam:AttachRolePolicy"
  fail=$((fail+1))
fi

echo
echo "== Trust policy intra-org =="
check_policy_structure "$P_TRUSTO" "trust-org"

if jq -e '[.Statement[] | .Action // empty] | flatten | map(tostring) | any(contains("sts:AssumeRole"))' "$P_TRUSTO" >/dev/null 2>&1; then
  echo "  OK   [trust-org] has sts:AssumeRole action"
else
  echo "  FAIL [trust-org] must have Action sts:AssumeRole"
  fail=$((fail+1))
fi

if grep -q 'aws:PrincipalOrgID' "$P_TRUSTO"; then
  echo "  OK   [trust-org] conditions on aws:PrincipalOrgID"
else
  echo "  FAIL [trust-org] intra-org trust MUST condition on aws:PrincipalOrgID"
  fail=$((fail+1))
fi

if jq -e '.Statement[] | .Principal | tostring | contains("AWS")' "$P_TRUSTO" >/dev/null 2>&1; then
  echo "  OK   [trust-org] has AWS principal"
else
  echo "  FAIL [trust-org] must declare AWS principal"
  fail=$((fail+1))
fi

if jq -e '.Statement[] | .Principal.AWS | tostring | contains("*") | not' "$P_TRUSTO" >/dev/null 2>&1; then
  echo "  OK   [trust-org] AWS principal is not wildcard"
else
  echo "  FAIL [trust-org] Principal.AWS must NOT be wildcard"
  fail=$((fail+1))
fi

echo
echo "== Trust policy vendor external =="
check_policy_structure "$P_TRUSTV" "trust-vendor"

if grep -q 'sts:ExternalId' "$P_TRUSTV"; then
  echo "  OK   [trust-vendor] conditions on sts:ExternalId"
else
  echo "  FAIL [trust-vendor] external vendor trust MUST condition on sts:ExternalId"
  fail=$((fail+1))
fi

if grep -q 'aws:PrincipalOrgID' "$P_TRUSTV"; then
  echo "  FAIL [trust-vendor] vendor is outside your org — aws:PrincipalOrgID would always fail"
  fail=$((fail+1))
else
  echo "  OK   [trust-vendor] does NOT use aws:PrincipalOrgID (vendor is external)"
fi

if jq -e '[.Statement[] | .Action // empty] | flatten | map(tostring) | any(contains("sts:AssumeRole"))' "$P_TRUSTV" >/dev/null 2>&1; then
  echo "  OK   [trust-vendor] has sts:AssumeRole action"
else
  echo "  FAIL [trust-vendor] must have Action sts:AssumeRole"
  fail=$((fail+1))
fi

echo
echo "== DECISIONS.md sections =="
for section in "A" "B" "C" "D" "E"; do
  if grep -qiE "^#+ *(Secci[óo]n +$section\b|$section\. )" "$DOC"; then
    echo "  OK   DECISIONS.md has Section $section"
  else
    echo "  FAIL DECISIONS.md missing Section $section"
    fail=$((fail+1))
  fi
done

for term in "boundary" "ExternalId" "PrincipalOrgID" "confused deputy"; do
  if grep -qi "$term" "$DOC"; then
    echo "  OK   DECISIONS.md mentions $term"
  else
    echo "  FAIL DECISIONS.md must mention $term"
    fail=$((fail+1))
  fi
done

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara DECISIONS.md y las policies con solution/ para autoevaluarte."
exit 0
