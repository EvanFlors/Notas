#!/usr/bin/env bash
# Structural validation for aws-07-01-publish-app-with-alb-tls-dns.
# Checks that Terraform files exist and reference the required resources,
# and that DECISIONS.md contains the three ADRs.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-07-alb}"
fail=0

echo "== Structural validation for $BASE =="

# --- Terraform files --------------------------------------------------------
for f in main.tf providers.tf; do
  if [ -f "$BASE/$f" ]; then
    echo "  OK   $f exists"
  else
    echo "  FAIL $BASE/$f missing"
    fail=$((fail+1))
  fi
done

MAIN="$BASE/main.tf"
if [ ! -f "$MAIN" ]; then
  echo "RESULT: cannot continue without main.tf"
  exit 1
fi

# Aggregate HCL (main + providers + variables if present) so students can split freely.
HCL=$(mktemp)
trap 'rm -f "$HCL"' EXIT
cat "$BASE"/*.tf > "$HCL" 2>/dev/null || true

check_contains() {
  pattern="$1"
  label="$2"
  if grep -qE "$pattern" "$HCL"; then
    echo "  OK   HCL contains $label"
  else
    echo "  FAIL HCL missing $label"
    fail=$((fail+1))
  fi
}

check_contains '"aws_lb"' 'aws_lb resource'
check_contains 'load_balancer_type[[:space:]]*=[[:space:]]*"application"' 'load_balancer_type = application'
check_contains '"aws_lb_target_group"' 'aws_lb_target_group resource'
check_contains '"aws_lb_listener"' 'aws_lb_listener resource'
check_contains 'port[[:space:]]*=[[:space:]]*443' 'listener on port 443'
check_contains 'protocol[[:space:]]*=[[:space:]]*"HTTPS"' 'protocol HTTPS'
check_contains 'HTTP_301' 'HTTP_301 redirect from 80'
check_contains '"aws_acm_certificate"' 'aws_acm_certificate resource'
check_contains 'validation_method[[:space:]]*=[[:space:]]*"DNS"' 'ACM DNS validation'
check_contains '"aws_acm_certificate_validation"' 'aws_acm_certificate_validation resource'
check_contains '"aws_route53_record"' 'aws_route53_record resource'
check_contains 'alias[[:space:]]*{' 'Route53 alias block'

# No real-looking Account IDs (12 digits other than our placeholder).
if grep -oE '[^0-9]([0-9]{12})[^0-9]' "$HCL" | grep -vE '012345678901' | grep -qE '[0-9]{12}'; then
  echo "  FAIL HCL seems to contain a 12-digit AWS Account ID that is not the placeholder 012345678901"
  fail=$((fail+1))
else
  echo "  OK   no suspicious real AWS Account IDs"
fi

# Must use the stub-friendly provider toggles so plan runs offline.
if grep -q 'skip_credentials_validation' "$HCL" && grep -q 'skip_requesting_account_id' "$HCL"; then
  echo "  OK   provider stub skips credentials validation (offline plan safe)"
else
  echo "  FAIL provider is not configured for offline plan (missing skip_credentials_validation / skip_requesting_account_id)"
  fail=$((fail+1))
fi

# --- DECISIONS.md ----------------------------------------------------------
DOC="$BASE/DECISIONS.md"
if [ ! -f "$DOC" ]; then
  echo "  FAIL $DOC missing"
  fail=$((fail+1))
else
  echo "  OK   DECISIONS.md exists"
  for n in 001 002 003; do
    if grep -qiE "^#+ *ADR-$n" "$DOC"; then
      echo "  OK   DECISIONS.md has ADR-$n"
    else
      echo "  FAIL DECISIONS.md missing ADR-$n heading"
      fail=$((fail+1))
    fi
  done

  # Each ADR should include "Decision" and "Consequences" cues.
  if grep -qiE 'decisi[óo]n' "$DOC" && grep -qiE 'consecuencias' "$DOC"; then
    echo "  OK   DECISIONS.md uses Decision/Consequences vocabulary"
  else
    echo "  FAIL DECISIONS.md lacks Decision/Consequences vocabulary"
    fail=$((fail+1))
  fi

  # Must mention ALB and NLB (ADR-001 compares them).
  if grep -qi 'ALB' "$DOC" && grep -qi 'NLB' "$DOC"; then
    echo "  OK   DECISIONS.md discusses ALB vs NLB"
  else
    echo "  FAIL DECISIONS.md does not discuss ALB vs NLB"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
