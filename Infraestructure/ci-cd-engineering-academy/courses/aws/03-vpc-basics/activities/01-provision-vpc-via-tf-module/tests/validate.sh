#!/usr/bin/env bash
# Structural validation for aws-03-01-provision-vpc-via-tf-module.
# Checks that main.tf and DESIGN.md exist and contain the required
# resources, CIDRs, and sections. Does NOT run terraform (students
# run it themselves) and does NOT grade semantic correctness; compare
# manually with solution/REFERENCE.md.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many
# checks use `... | grep -q ...` which can produce SIGPIPE (exit 141)
# when grep finds a match early. pipefail would spuriously mark those
# as failures.

set -eu

BASE="${1:-/tmp/aws-03-vpc-module}"
MAIN="$BASE/main.tf"
DESIGN="$BASE/DESIGN.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$MAIN" ]; then
  echo "FAIL: $MAIN does not exist. Student must produce it."
  exit 1
fi

if [ ! -f "$DESIGN" ]; then
  echo "FAIL: $DESIGN does not exist. Student must produce it."
  exit 1
fi

# ---- main.tf checks ----

# VPC resource with /16.
if grep -qE 'resource[[:space:]]+"aws_vpc"' "$MAIN"; then
  echo "  OK   main.tf declares aws_vpc"
else
  echo "  FAIL main.tf missing aws_vpc resource"
  fail=$((fail+1))
fi

if grep -qE 'cidr_block[[:space:]]*=[[:space:]]*"10\.0\.0\.0/16"' "$MAIN"; then
  echo "  OK   main.tf uses 10.0.0.0/16"
else
  echo "  FAIL main.tf does not declare cidr_block = \"10.0.0.0/16\""
  fail=$((fail+1))
fi

# DNS flags on.
if grep -qE 'enable_dns_hostnames[[:space:]]*=[[:space:]]*true' "$MAIN"; then
  echo "  OK   main.tf enables dns_hostnames"
else
  echo "  FAIL main.tf must set enable_dns_hostnames = true"
  fail=$((fail+1))
fi

# IGW.
if grep -qE 'resource[[:space:]]+"aws_internet_gateway"' "$MAIN"; then
  echo "  OK   main.tf declares aws_internet_gateway"
else
  echo "  FAIL main.tf missing aws_internet_gateway"
  fail=$((fail+1))
fi

# Subnets (public + private).
if grep -qE 'resource[[:space:]]+"aws_subnet"[[:space:]]+"public"' "$MAIN"; then
  echo "  OK   main.tf declares aws_subnet.public"
else
  echo "  FAIL main.tf missing aws_subnet.public"
  fail=$((fail+1))
fi

if grep -qE 'resource[[:space:]]+"aws_subnet"[[:space:]]+"private"' "$MAIN"; then
  echo "  OK   main.tf declares aws_subnet.private"
else
  echo "  FAIL main.tf missing aws_subnet.private"
  fail=$((fail+1))
fi

# Public route table with 0.0.0.0/0.
if grep -qE 'cidr_block[[:space:]]*=[[:space:]]*"0\.0\.0\.0/0"' "$MAIN"; then
  echo "  OK   main.tf has a 0.0.0.0/0 route (public RT)"
else
  echo "  FAIL main.tf missing 0.0.0.0/0 route for public RT"
  fail=$((fail+1))
fi

# S3 Gateway endpoint.
if grep -qE 'resource[[:space:]]+"aws_vpc_endpoint"' "$MAIN"; then
  echo "  OK   main.tf declares aws_vpc_endpoint"
else
  echo "  FAIL main.tf missing aws_vpc_endpoint (S3 Gateway)"
  fail=$((fail+1))
fi

if grep -qi 's3' "$MAIN"; then
  echo "  OK   main.tf mentions s3 (expected: S3 Gateway endpoint)"
else
  echo "  FAIL main.tf does not mention s3"
  fail=$((fail+1))
fi

# Mock provider skips so plan runs offline.
skips_ok=0
for s in skip_credentials_validation skip_requesting_account_id skip_metadata_api_check; do
  if grep -q "$s" "$MAIN"; then
    skips_ok=$((skips_ok+1))
  fi
done
if [ "$skips_ok" -ge 3 ]; then
  echo "  OK   main.tf provider has all 3 skip_* flags (offline plan)"
else
  echo "  FAIL main.tf provider must set the 3 skip_* flags for offline plan ($skips_ok/3)"
  fail=$((fail+1))
fi

# Guard against apply having been executed (presence of .tfstate with resources).
if [ -f "$BASE/terraform.tfstate" ] && grep -q '"resources":' "$BASE/terraform.tfstate" 2>/dev/null; then
  if grep -q '"instances":[[:space:]]*\[[[:space:]]*{' "$BASE/terraform.tfstate" 2>/dev/null; then
    echo "  FAIL terraform.tfstate contains resource instances: did you run 'apply'? This activity is plan-only."
    fail=$((fail+1))
  fi
fi

# ---- DESIGN.md checks ----

if grep -qiE '^#+ *CIDR' "$DESIGN"; then
  echo "  OK   DESIGN.md has CIDR section"
else
  echo "  FAIL DESIGN.md missing CIDR section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *Diagrama' "$DESIGN"; then
  echo "  OK   DESIGN.md has Diagrama section"
else
  echo "  FAIL DESIGN.md missing Diagrama section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *Decisiones' "$DESIGN"; then
  echo "  OK   DESIGN.md has Decisiones section"
else
  echo "  FAIL DESIGN.md missing Decisiones section"
  fail=$((fail+1))
fi

# ASCII diagram cues.
if grep -qE '[-+|]{3,}' "$DESIGN"; then
  echo "  OK   DESIGN.md looks like it contains an ASCII diagram"
else
  echo "  FAIL DESIGN.md must contain an ASCII diagram (---, |||, +++...)"
  fail=$((fail+1))
fi

# Must mention key pieces.
pieces=0
for p in "igw" "route" "endpoint" "s3" "private" "public"; do
  if grep -qi "$p" "$DESIGN"; then
    pieces=$((pieces+1))
  fi
done
if [ "$pieces" -ge 5 ]; then
  echo "  OK   DESIGN.md mentions at least 5 core pieces ($pieces)"
else
  echo "  FAIL DESIGN.md mentions only $pieces core pieces (expected >=5)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara main.tf y DESIGN.md con solution/REFERENCE.md."
exit 0
