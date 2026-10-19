#!/usr/bin/env bash
# Structural validation for aws-16-02-ecr-scan-gate-in-pipeline.
# Verifies that the 4 artifacts exist (terraform/, workflow, ADR), that the
# HCL enforces scan_on_push + IMMUTABLE + KMS, that the workflow has an OIDC
# login and a gate on CRITICAL/HIGH findings, and that the ADR covers the
# required points. Optionally runs `terraform validate`, `checkov` and
# `trivy` if installed; otherwise SKIP (not a failure).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness of the ADR — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-16-02-ecr}"
TF="$BASE/terraform"
WF="$BASE/.github/workflows/build-scan-gate.yml"
ADR="$BASE/ADR-ecr-scanning-tier.md"
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
  echo "  OK   .github/workflows/build-scan-gate.yml exists"
else
  echo "  FAIL .github/workflows/build-scan-gate.yml missing"
  fail=$((fail+1))
fi

if [ -f "$ADR" ]; then
  echo "  OK   ADR-ecr-scanning-tier.md exists"
else
  echo "  FAIL ADR-ecr-scanning-tier.md missing"
  fail=$((fail+1))
fi

# Short-circuit if critical files are missing.
if [ "$fail" -gt 0 ]; then
  echo
  echo "RESULT: $fail prerequisite file(s) missing. Create them before further checks."
  exit 1
fi

MAIN_TF="$TF/main.tf"

# --- HCL content: ECR repo hardening ----------------------------------------
if grep -qE 'aws_ecr_repository' "$MAIN_TF"; then
  echo "  OK   main.tf declares aws_ecr_repository"
else
  echo "  FAIL main.tf missing aws_ecr_repository"
  fail=$((fail+1))
fi

if grep -qE 'image_tag_mutability[[:space:]]*=[[:space:]]*"IMMUTABLE"' "$MAIN_TF"; then
  echo "  OK   main.tf sets image_tag_mutability = IMMUTABLE"
else
  echo "  FAIL main.tf does not set image_tag_mutability = IMMUTABLE"
  fail=$((fail+1))
fi

if grep -qE 'scan_on_push[[:space:]]*=[[:space:]]*true' "$MAIN_TF"; then
  echo "  OK   main.tf sets scan_on_push = true"
else
  echo "  FAIL main.tf does not set scan_on_push = true"
  fail=$((fail+1))
fi

if grep -qE 'encryption_type[[:space:]]*=[[:space:]]*"KMS"' "$MAIN_TF"; then
  echo "  OK   main.tf uses encryption_type = KMS"
else
  echo "  FAIL main.tf does not use encryption_type = KMS"
  fail=$((fail+1))
fi

if grep -qE 'aws_ecr_lifecycle_policy' "$MAIN_TF"; then
  echo "  OK   main.tf declares aws_ecr_lifecycle_policy"
else
  echo "  FAIL main.tf missing aws_ecr_lifecycle_policy (bloat prevention)"
  fail=$((fail+1))
fi

# --- Anti-patterns: MUTABLE, scan_on_push=false, access keys ----------------
if grep -qE 'image_tag_mutability[[:space:]]*=[[:space:]]*"MUTABLE"' "$MAIN_TF"; then
  echo "  FAIL main.tf uses image_tag_mutability = MUTABLE (anti-pattern)"
  fail=$((fail+1))
else
  echo "  OK   main.tf does not use MUTABLE tags"
fi

if grep -qE 'scan_on_push[[:space:]]*=[[:space:]]*false' "$MAIN_TF"; then
  echo "  FAIL main.tf disables scan_on_push (anti-pattern)"
  fail=$((fail+1))
else
  echo "  OK   main.tf does not disable scan_on_push"
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

if grep -qE 'docker build' "$WF"; then
  echo "  OK   workflow does docker build"
else
  echo "  FAIL workflow does not do docker build"
  fail=$((fail+1))
fi

if grep -qE 'docker push' "$WF"; then
  echo "  OK   workflow does docker push"
else
  echo "  FAIL workflow does not do docker push"
  fail=$((fail+1))
fi

if grep -qE 'describe-image-scan-findings' "$WF"; then
  echo "  OK   workflow calls ecr describe-image-scan-findings"
else
  echo "  FAIL workflow does not call ecr describe-image-scan-findings"
  fail=$((fail+1))
fi

# Gate must fail on CRITICAL/HIGH: look for both terms AND an exit 1 somewhere.
if grep -qE 'CRITICAL' "$WF" && grep -qE 'HIGH' "$WF"; then
  echo "  OK   workflow references CRITICAL and HIGH severities"
else
  echo "  FAIL workflow does not reference both CRITICAL and HIGH severities"
  fail=$((fail+1))
fi

if grep -qE 'exit 1' "$WF"; then
  echo "  OK   workflow has exit 1 (gate can fail the pipeline)"
else
  echo "  FAIL workflow has no exit 1 (gate cannot fail the pipeline)"
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

if grep -qiE '\bbasic\b' "$ADR"; then
  echo "  OK   ADR mentions basic scanning"
else
  echo "  FAIL ADR does not mention basic scanning"
  fail=$((fail+1))
fi

if grep -qiE '\benhanced\b' "$ADR"; then
  echo "  OK   ADR mentions enhanced scanning"
else
  echo "  FAIL ADR does not mention enhanced scanning"
  fail=$((fail+1))
fi

if grep -qiE 'inspector' "$ADR"; then
  echo "  OK   ADR mentions Inspector"
else
  echo "  FAIL ADR does not mention Inspector"
  fail=$((fail+1))
fi

# Must cite at least one explicit monetary cost figure (e.g. $0.09, USD, mes).
if grep -qE '\$0?\.[0-9]+|\$[0-9]+|USD' "$ADR"; then
  echo "  OK   ADR cites explicit cost figures"
else
  echo "  FAIL ADR does not cite explicit cost figures (needed for defensibility)"
  fail=$((fail+1))
fi

# --- Optional: terraform validate -------------------------------------------
# We create a scratch copy to avoid polluting the student's directory with
# .terraform/ noise. SIGPIPE note: terraform output piped to grep is fine
# because we are not using pipefail.
if command -v terraform >/dev/null 2>&1; then
  SCRATCH="$(mktemp -d -t aws-16-02-tfvalidate-XXXXXX)"
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
