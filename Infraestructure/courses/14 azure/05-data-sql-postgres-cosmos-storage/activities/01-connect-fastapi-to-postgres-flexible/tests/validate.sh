#!/usr/bin/env bash
# Structural validation for az-05-01-connect-fastapi-to-postgres-flexible.
# Checks that TOPOLOGY.md exists in the scratch dir and contains the required
# sections, vocabulary and findings for a Postgres Flexible + Azure SQL audit.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which may trigger SIGPIPE (exit 141) when grep
# matches early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/az-05-pg}"
DOC="$BASE/TOPOLOGY.md"
TF="$BASE/main.tf"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

if [ ! -f "$TF" ]; then
  echo "  WARN main.tf not present at $TF (copy from starter/ expected)"
fi

# Required four sections (A, B, C, D).
for sec in A B C D; do
  if grep -qiE "^#+ *${sec}([.)]| +[-—–])" "$DOC"; then
    echo "  OK   TOPOLOGY.md has section ${sec}"
  else
    echo "  FAIL TOPOLOGY.md missing section ${sec} heading"
    fail=$((fail+1))
  fi
done

# Must mention at least 2 'Hallazgo' tokens.
hallazgos=$(grep -ciE 'hallazgo' "$DOC" || true)
if [ "$hallazgos" -ge 2 ]; then
  echo "  OK   TOPOLOGY.md mentions at least 2 'hallazgo' tokens ($hallazgos found)"
else
  echo "  FAIL TOPOLOGY.md mentions only $hallazgos 'hallazgo' tokens (expected >=2)"
  fail=$((fail+1))
fi

# Postgres must be mentioned.
if grep -qi 'postgres' "$DOC"; then
  echo "  OK   mentions Postgres"
else
  echo "  FAIL does not mention Postgres"
  fail=$((fail+1))
fi

# Azure SQL comparison.
if grep -qiE 'azure +sql|mssql|sql +database' "$DOC"; then
  echo "  OK   mentions Azure SQL / mssql / SQL Database"
else
  echo "  FAIL does not mention Azure SQL for the comparison"
  fail=$((fail+1))
fi

# HA / multi-AZ equivalent: zone-redundant, multi-AZ, HA.
if grep -qiE 'zone[- ]?redundant|multi[- ]?az|\bHA\b|high[- ]?availability' "$DOC"; then
  echo "  OK   mentions HA / zone-redundant / multi-AZ"
else
  echo "  FAIL does not mention HA / zone-redundant / multi-AZ"
  fail=$((fail+1))
fi

# RPO / RTO.
if grep -qiE '\brpo\b|\brto\b' "$DOC"; then
  echo "  OK   mentions RPO/RTO"
else
  echo "  FAIL does not mention RPO or RTO"
  fail=$((fail+1))
fi

# Private access / Private Endpoint / NSG / subnet delegada → "network control".
if grep -qiE 'private +endpoint|private +access|subnet +delega|\bNSG\b|security +group' "$DOC"; then
  echo "  OK   mentions Private Endpoint / Private Access / NSG / delegated subnet"
else
  echo "  FAIL does not mention network control (Private Endpoint / Private Access / NSG / delegated subnet)"
  fail=$((fail+1))
fi

# Auth: Entra ID / Azure AD / IAM auth.
if grep -qiE 'entra +id|azure +ad|aad|iam[- ]?(auth|database)' "$DOC"; then
  echo "  OK   mentions Entra ID / Azure AD / IAM auth"
else
  echo "  FAIL does not mention Entra ID / Azure AD authentication"
  fail=$((fail+1))
fi

# backup / retention / snapshot.
if grep -qiE 'backup|snapshot|retention' "$DOC"; then
  echo "  OK   mentions backup/snapshot/retention"
else
  echo "  FAIL does not mention backup/snapshot/retention"
  fail=$((fail+1))
fi

# At least two Terraform attribute names explicitly cited.
tf_terms=0
for term in "public_network_access_enabled" "delegated_subnet_id" \
            "private_dns_zone_id" "high_availability" \
            "active_directory_auth_enabled" "password_auth_enabled" \
            "backup_retention_days" "administrator_login" \
            "sku_name" "zone_redundant"; do
  if grep -q "$term" "$DOC"; then
    tf_terms=$((tf_terms+1))
  fi
done
if [ "$tf_terms" -ge 2 ]; then
  echo "  OK   cites at least 2 Terraform attribute names ($tf_terms found)"
else
  echo "  FAIL cites only $tf_terms Terraform attribute names (expected >=2)"
  fail=$((fail+1))
fi

# SQL schema evidence: CREATE TABLE present in doc OR a schema.sql file.
if grep -qiE 'CREATE +TABLE' "$DOC" || [ -f "$BASE/schema.sql" ]; then
  echo "  OK   SQL schema present (CREATE TABLE in doc or schema.sql file)"
else
  echo "  FAIL no CREATE TABLE in doc and no schema.sql file"
  fail=$((fail+1))
fi

# Index justification.
if grep -qiE '\bindex\b|\b[ií]ndice\b' "$DOC"; then
  echo "  OK   mentions index / indice (section C justification)"
else
  echo "  FAIL does not justify any index"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara TOPOLOGY.md con solution/REFERENCE.md para autoevaluarte."
exit 0
