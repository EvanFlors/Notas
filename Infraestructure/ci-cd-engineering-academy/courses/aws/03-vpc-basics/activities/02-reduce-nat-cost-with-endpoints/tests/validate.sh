#!/usr/bin/env bash
# Structural validation for aws-03-02-reduce-nat-cost-with-endpoints.
# Checks that COST-ANALYSIS.md exists and contains the 4 sections,
# the classification table, at least 5 numbered recommendations,
# and the canonical pieces (S3, DynamoDB, ECR, NAT, endpoints).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many
# checks use `... | grep -q ...` which can produce SIGPIPE (exit 141)
# when grep finds a match early. pipefail would spuriously mark those
# as failures.
#
# Does NOT grade semantic correctness — compare with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-03-nat-endpoints}"
DOC="$BASE/COST-ANALYSIS.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# ---- 4 sections ----
if grep -qiE '^#+ *(Secci[oó]n +A|Clasificaci[oó]n)' "$DOC"; then
  echo "  OK   has Section A (Clasificacion)"
else
  echo "  FAIL missing Section A / Clasificacion heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[oó]n +B|C[aá]lculo)' "$DOC"; then
  echo "  OK   has Section B (Calculo)"
else
  echo "  FAIL missing Section B / Calculo heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[oó]n +C|Diagrama|Antes|Despu[eé]s)' "$DOC"; then
  echo "  OK   has Section C (Diagrama antes/despues)"
else
  echo "  FAIL missing Section C / Diagrama heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[oó]n +D|Recomendaciones)' "$DOC"; then
  echo "  OK   has Section D (Recomendaciones)"
else
  echo "  FAIL missing Section D / Recomendaciones heading"
  fail=$((fail+1))
fi

# ---- classification table >= 7 rows ----
rows=$(grep -cE '^\|' "$DOC")
if [ "$rows" -ge 9 ]; then
  echo "  OK   table has at least 7 data rows ($rows pipe-lines, incl. header+sep)"
else
  echo "  FAIL table has only $rows pipe-lines (expected >=9: header+sep+7 rows)"
  fail=$((fail+1))
fi

# ---- canonical pieces ----
pieces=0
for p in "s3" "dynamodb" "ecr" "nat" "endpoint"; do
  if grep -qi "$p" "$DOC"; then
    pieces=$((pieces+1))
  fi
done
if [ "$pieces" -ge 5 ]; then
  echo "  OK   mentions the 5 canonical pieces (S3/DynamoDB/ECR/NAT/endpoint)"
else
  echo "  FAIL only $pieces canonical pieces mentioned (expected 5)"
  fail=$((fail+1))
fi

# ---- classification vocabulary ----
if grep -qiE 'gateway endpoint' "$DOC"; then
  echo "  OK   mentions Gateway endpoint"
else
  echo "  FAIL does not mention 'Gateway endpoint'"
  fail=$((fail+1))
fi

if grep -qiE 'interface endpoint' "$DOC"; then
  echo "  OK   mentions Interface endpoint"
else
  echo "  FAIL does not mention 'Interface endpoint'"
  fail=$((fail+1))
fi

# ---- cost cue: must mention $ figure or 0.045 (NAT per-GB) or ahorro ----
if grep -qiE '0\.045|\$[0-9]|ahorro' "$DOC"; then
  echo "  OK   contains cost figures / ahorro"
else
  echo "  FAIL does not show cost figures ($, 0.045, or 'ahorro')"
  fail=$((fail+1))
fi

# ---- ASCII diagram cue ----
if grep -qE '[-+|]{3,}' "$DOC"; then
  echo "  OK   contains an ASCII diagram"
else
  echo "  FAIL must contain an ASCII diagram (---, |||, +++...)"
  fail=$((fail+1))
fi

# ---- 5 numbered recommendations ----
recs=0
for n in 1 2 3 4 5; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    recs=$((recs+1))
  fi
done
if [ "$recs" -ge 5 ]; then
  echo "  OK   has at least 5 numbered recommendations"
else
  echo "  FAIL has $recs numbered recommendations (expected >=5)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara COST-ANALYSIS.md con solution/REFERENCE.md."
exit 0
