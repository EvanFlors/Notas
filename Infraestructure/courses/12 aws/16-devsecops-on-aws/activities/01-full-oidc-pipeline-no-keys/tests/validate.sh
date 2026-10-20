#!/usr/bin/env bash
# Structural validation for aws-16-01-full-oidc-pipeline-no-keys.
# Verifies that the 4 artifacts exist (terraform/, workflow, ADR), that the
# HCL avoids known OIDC anti-patterns (wildcard sub, hardcoded access keys),
# that the workflow uses OIDC properly, and that the ADR covers the required
# points. Optionally runs `terraform validate`, `checkov` and `trivy` if they
# are installed; otherwise SKIP (not a failure).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness of the ADR — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-16-01-oidc}"
TF="$BASE/terraform"
WF="$BASE/.github/workflows/deploy.yml"
ADR="$BASE/ADR-oidc-sub-pinning.md"
fail=0

echo "== Structural validation for $BASE =="

# --- Existence checks --------------------------------------------------------
if [ -d "$TF" ]; then
  echo "  OK   terraform/ directory exists"
else
  echo "  FAIL terraform/ directory missing"
  fail=$((fail+1))
fi

for f in "$TF/main.tf" "$TF/variables.tf" "$TF/outputs.tf"; do
  if [ -f "$f" ]; then
    echo "  OK   $(basename "$f") exists"
  else
    echo "  FAIL $(basename "$f") missing"
    fail=$((fail+1))
  fi
done

if [ -f "$WF" ]; then
  echo "  OK   .github/workflows/deploy.yml exists"
else
  echo "  FAIL .github/workflows/deploy.yml missing"
  fail=$((fail+1))
fi

if [ -f "$ADR" ]; then
  echo "  OK   ADR-oidc-sub-pinning.md exists"
else
  echo "  FAIL ADR-oidc-sub-pinning.md missing"
  fail=$((fail+1))
fi

# Short-circuit if critical files are missing.
if [ "$fail" -gt 0 ]; then
  echo
  echo "RESULT: $fail prerequisite file(s) missing. Create them before further checks."
  exit 1
fi

MAIN_TF="$TF/main.tf"

# --- HCL content: OIDC provider ---------------------------------------------
if grep -qE 'aws_iam_openid_connect_provider' "$MAIN_TF"; then
  echo "  OK   main.tf declares aws_iam_openid_connect_provider"
else
  echo "  FAIL main.tf missing aws_iam_openid_connect_provider"
  fail=$((fail+1))
fi

if grep -qE 'token\.actions\.githubusercontent\.com' "$MAIN_TF"; then
  echo "  OK   main.tf references token.actions.githubusercontent.com"
else
  echo "  FAIL main.tf does not reference token.actions.githubusercontent.com"
  fail=$((fail+1))
fi

if grep -qE 'sts\.amazonaws\.com' "$MAIN_TF"; then
  echo "  OK   main.tf references sts.amazonaws.com (aud)"
else
  echo "  FAIL main.tf does not reference sts.amazonaws.com"
  fail=$((fail+1))
fi

# --- HCL content: IAM Role with trust policy --------------------------------
if grep -qE 'aws_iam_role' "$MAIN_TF"; then
  echo "  OK   main.tf declares aws_iam_role"
else
  echo "  FAIL main.tf missing aws_iam_role"
  fail=$((fail+1))
fi

if grep -qE 'AssumeRoleWithWebIdentity' "$MAIN_TF"; then
  echo "  OK   main.tf uses sts:AssumeRoleWithWebIdentity"
else
  echo "  FAIL main.tf does not use sts:AssumeRoleWithWebIdentity"
  fail=$((fail+1))
fi

if grep -qE 'StringEquals' "$MAIN_TF"; then
  echo "  OK   main.tf uses StringEquals condition"
else
  echo "  FAIL main.tf does not use StringEquals (sub should be pinned exactly)"
  fail=$((fail+1))
fi

# --- Anti-patterns: wildcard sub, access keys -------------------------------
# Reject StringLike combined with a wildcard sub ending in :* .
# Also reject a literal "sub" value of "repo:*".
if grep -qE '"token\.actions\.githubusercontent\.com:sub"[[:space:]]*=[[:space:]]*"repo:\*"' "$MAIN_TF"; then
  echo "  FAIL main.tf uses wildcard sub \"repo:*\" (critical anti-pattern)"
  fail=$((fail+1))
elif grep -qE 'StringLike' "$MAIN_TF" && grep -qE '"token\.actions\.githubusercontent\.com:sub"[[:space:]]*=[[:space:]]*"[^"]*\*' "$MAIN_TF"; then
  echo "  FAIL main.tf combines StringLike with wildcard sub (anti-pattern)"
  fail=$((fail+1))
else
  echo "  OK   main.tf does not use wildcard sub"
fi

if grep -qiE 'aws_access_key_id|aws_secret_access_key' "$MAIN_TF" "$TF/variables.tf" "$TF/outputs.tf" "$WF"; then
  echo "  FAIL hardcoded AWS access keys referenced (critical anti-pattern)"
  fail=$((fail+1))
else
  echo "  OK   no AWS access keys referenced"
fi

# --- Workflow checks --------------------------------------------------------
if grep -qE 'aws-actions/configure-aws-credentials@v[0-9]' "$WF"; then
  echo "  OK   workflow uses aws-actions/configure-aws-credentials"
else
  echo "  FAIL workflow does not use aws-actions/configure-aws-credentials"
  fail=$((fail+1))
fi

if grep -qE 'id-token:[[:space:]]*write' "$WF"; then
  echo "  OK   workflow declares id-token: write"
else
  echo "  FAIL workflow does not declare id-token: write"
  fail=$((fail+1))
fi

if grep -qE 'role-to-assume' "$WF"; then
  echo "  OK   workflow passes role-to-assume"
else
  echo "  FAIL workflow does not pass role-to-assume"
  fail=$((fail+1))
fi

# --- ADR checks -------------------------------------------------------------
for section in "Context" "Decision" "Consequences" "Alternatives"; do
  if grep -qiE "^#+ *${section}" "$ADR"; then
    echo "  OK   ADR has '${section}' section"
  else
    echo "  FAIL ADR missing '${section}' section"
    fail=$((fail+1))
  fi
done

if grep -qiE '\bsub\b' "$ADR"; then
  echo "  OK   ADR mentions sub claim"
else
  echo "  FAIL ADR does not mention sub claim"
  fail=$((fail+1))
fi

if grep -qiE 'StringEquals|StringLike' "$ADR"; then
  echo "  OK   ADR discusses StringEquals/StringLike"
else
  echo "  FAIL ADR does not discuss StringEquals/StringLike"
  fail=$((fail+1))
fi

if grep -qiE 'wildcard|comod[ií]n|repo:\*' "$ADR"; then
  echo "  OK   ADR discusses wildcard anti-pattern"
else
  echo "  FAIL ADR does not discuss wildcard anti-pattern"
  fail=$((fail+1))
fi

patterns_found=0
for p in "refs/heads/main" "environment:" "refs/tags/"; do
  if grep -qE "$p" "$ADR"; then
    patterns_found=$((patterns_found+1))
  fi
done
if [ "$patterns_found" -ge 3 ]; then
  echo "  OK   ADR names 3+ sub patterns ($patterns_found found)"
else
  echo "  FAIL ADR names only $patterns_found sub patterns (expected 3)"
  fail=$((fail+1))
fi

# --- Optional: terraform validate -------------------------------------------
# We create a scratch copy to avoid polluting the student's directory with
# .terraform/ noise. SIGPIPE note: terraform output piped to grep is fine
# because we are not using pipefail.
if command -v terraform >/dev/null 2>&1; then
  SCRATCH="$(mktemp -d -t aws-16-01-tfvalidate-XXXXXX)"
  trap 'rm -rf "$SCRATCH"' EXIT
  cp -R "$TF/." "$SCRATCH/"
  if ( cd "$SCRATCH" && terraform init -backend=false -input=false >/dev/null 2>&1 && terraform validate >/dev/null 2>&1 ); then
    echo "  OK   terraform validate passes"
  else
    echo "  FAIL terraform validate failed"
    fail=$((fail+1))
  fi
else
  echo "  SKIP terraform not installed (skipping terraform validate)"
fi

# --- Optional: checkov ------------------------------------------------------
if command -v checkov >/dev/null 2>&1; then
  if checkov -d "$TF" --quiet --compact >/dev/null 2>&1; then
    echo "  OK   checkov passes on terraform/"
  else
    # Checkov non-zero exit may be acceptable depending on policy; downgrade
    # to a warning so the activity does not block on opinionated rules.
    echo "  WARN checkov reported findings (review output: checkov -d $TF)"
  fi
else
  echo "  SKIP checkov not installed"
fi

# --- Optional: trivy --------------------------------------------------------
if command -v trivy >/dev/null 2>&1; then
  if trivy config --quiet --exit-code 0 "$TF" >/dev/null 2>&1; then
    echo "  OK   trivy config scan ran on terraform/"
  else
    echo "  WARN trivy reported findings (review: trivy config $TF)"
  fi
else
  echo "  SKIP trivy not installed"
fi

# ----------------------------------------------------------------------------
echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness of the ADR is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR y HCL con solution/REFERENCE.md para autoevaluarte."
exit 0
