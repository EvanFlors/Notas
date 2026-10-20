#!/usr/bin/env bash
# Structural validation for sec-02-01-audit-your-secrets.
# Checks that INVENTORY.md exists and contains the required sections,
# a classification table with >=5 rows, the required columns, the
# families and homes vocabulary, and the short-lived marker.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/sec-02-audit}"
DOC="$BASE/INVENTORY.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Required sections (A, B, C, D).
if grep -qiE '^#+ *(Secci[óo]n +A|Contexto)' "$DOC"; then
  echo "  OK   has Section A (Contexto)"
else
  echo "  FAIL missing Section A / Contexto heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +B|Inventario|Tabla)' "$DOC"; then
  echo "  OK   has Section B (Inventario)"
else
  echo "  FAIL missing Section B / Inventario heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +C|Top|Riesgos)' "$DOC"; then
  echo "  OK   has Section C (Top riesgos)"
else
  echo "  FAIL missing Section C / Top riesgos heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +D|Migraci[óo]n|Plan)' "$DOC"; then
  echo "  OK   has Section D (Plan de migracion)"
else
  echo "  FAIL missing Section D / Plan heading"
  fail=$((fail+1))
fi

# Table must have at least 5 inventory rows: look for pipes '|' at least 7 times
# (header + separator + 5 rows = 7 lines starting with '|').
rows=$(grep -cE '^\|' "$DOC")
if [ "$rows" -ge 7 ]; then
  echo "  OK   table has at least 5 rows ($rows pipe-lines found)"
else
  echo "  FAIL table has only $rows pipe-lines (expected >=7)"
  fail=$((fail+1))
fi

# Required column headers.
if grep -qiE 'secret_id' "$DOC"; then
  echo "  OK   has column secret_id"
else
  echo "  FAIL missing column secret_id"
  fail=$((fail+1))
fi

if grep -qiE 'familia' "$DOC"; then
  echo "  OK   has column familia"
else
  echo "  FAIL missing column familia"
  fail=$((fail+1))
fi

if grep -qiE 'hogar' "$DOC"; then
  echo "  OK   has column hogar"
else
  echo "  FAIL missing column hogar"
  fail=$((fail+1))
fi

if grep -qiE 'blast[_ ]?radius' "$DOC"; then
  echo "  OK   has column blast_radius"
else
  echo "  FAIL missing column blast_radius"
  fail=$((fail+1))
fi

if grep -qiE 'short[_ ]?lived' "$DOC"; then
  echo "  OK   has column short_lived"
else
  echo "  FAIL missing column short_lived"
  fail=$((fail+1))
fi

# Must mention at least 3 canonical families.
families=0
for f in "api-key" "db-cred" "oauth" "cert" "ssh" "signing" "encryption"; do
  if grep -qi "$f" "$DOC"; then
    families=$((families+1))
  fi
done
if [ "$families" -ge 3 ]; then
  echo "  OK   mentions at least 3 secret families ($families found)"
else
  echo "  FAIL mentions only $families secret families (expected >=3)"
  fail=$((fail+1))
fi

# Must mention at least one short-lived mechanism (OIDC/WI/STS/dynamic/keyless).
if grep -qiE 'oidc|workload identity|sts|dynamic|keyless' "$DOC"; then
  echo "  OK   mentions a short-lived mechanism"
else
  echo "  FAIL does not mention OIDC/Workload Identity/STS/dynamic/keyless"
  fail=$((fail+1))
fi

# Must mention at least one secret manager / KMS option.
if grep -qiE 'secret[s]? manager|vault|key vault|kms'  "$DOC"; then
  echo "  OK   mentions secret manager/KMS/Vault"
else
  echo "  FAIL does not mention a secret manager, KMS or Vault"
  fail=$((fail+1))
fi

# At least one row flagged yes/candidate for short-lived migration.
if grep -qiE 'yes|candidate' "$DOC"; then
  echo "  OK   has at least one row marked yes/candidate for short-lived"
else
  echo "  FAIL no row marked yes/candidate for short-lived"
  fail=$((fail+1))
fi

# Must use blast radius vocabulary.
if grep -qiE 'bajo|medio|alto|catastr[óo]fico'  "$DOC"; then
  echo "  OK   uses blast_radius vocabulary (bajo/medio/alto/catastrofico)"
else
  echo "  FAIL does not use blast_radius vocabulary"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara INVENTORY.md con solution/REFERENCE.md para autoevaluarte."
exit 0
