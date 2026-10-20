#!/usr/bin/env bash
# Structural validation for aws-08-01-provision-rds-and-connect.
# Checks that TOPOLOGY.md exists in the scratch dir and contains the required
# sections, vocabulary and findings.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which may trigger SIGPIPE (exit 141) when grep
# matches early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-08-rds}"
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

# Must mention at least 2 findings (either as 'Hallazgo' or numbered items in section A).
hallazgos=$(grep -ciE 'hallazgo' "$DOC" || true)
if [ "$hallazgos" -ge 2 ]; then
  echo "  OK   TOPOLOGY.md mentions at least 2 'hallazgo' tokens ($hallazgos found)"
else
  echo "  FAIL TOPOLOGY.md mentions only $hallazgos 'hallazgo' tokens (expected >=2)"
  fail=$((fail+1))
fi

# Required vocabulary: multi-AZ.
if grep -qiE 'multi[- ]?az' "$DOC"; then
  echo "  OK   mentions multi-AZ"
else
  echo "  FAIL does not mention multi-AZ"
  fail=$((fail+1))
fi

# RPO / RTO.
if grep -qiE '\brpo\b|\brto\b' "$DOC"; then
  echo "  OK   mentions RPO/RTO"
else
  echo "  FAIL does not mention RPO or RTO"
  fail=$((fail+1))
fi

# Security Group reference.
if grep -qiE 'security[- ]?group|\bsg\b'  "$DOC"; then
  echo "  OK   mentions Security Group"
else
  echo "  FAIL does not mention Security Group"
  fail=$((fail+1))
fi

# IAM / auth.
if grep -qiE 'iam[- ]?(auth|database|db)|iam_database_authentication' "$DOC"; then
  echo "  OK   mentions IAM auth / IAM database authentication"
else
  echo "  FAIL does not mention IAM auth"
  fail=$((fail+1))
fi

# backup / retention / snapshot.
if grep -qiE 'backup|snapshot|retention'  "$DOC"; then
  echo "  OK   mentions backup/snapshot/retention"
else
  echo "  FAIL does not mention backup/snapshot/retention"
  fail=$((fail+1))
fi

# At least one Terraform attribute name explicitly cited.
tf_terms=0
for term in "publicly_accessible" "deletion_protection" "storage_encrypted" \
            "multi_az" "skip_final_snapshot" "iam_database_authentication_enabled" \
            "manage_master_user_password" "backup_retention_period"; do
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

# SQL schema evidence: CREATE TABLE present in the doc OR an accompanying schema.sql.
if grep -qiE 'CREATE +TABLE' "$DOC" || [ -f "$BASE/schema.sql" ]; then
  echo "  OK   SQL schema present (CREATE TABLE in doc or schema.sql file)"
else
  echo "  FAIL no CREATE TABLE in doc and no schema.sql file"
  fail=$((fail+1))
fi

# Index justification: mentions 'index' / 'indice'.
if grep -qiE '\bindex\b|\b[ií]ndice\b' "$DOC"; then
  echo "  OK   mentions index / indice (section C justification)"
else
  echo "  FAIL does not justify any index"
  fail=$((fail+1))
fi

# Must mention Postgres explicitly.
if grep -qi 'postgres' "$DOC"; then
  echo "  OK   mentions Postgres"
else
  echo "  FAIL does not mention Postgres"
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
