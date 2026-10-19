#!/usr/bin/env bash
# Structural validation for aws-17-02-finops-dashboard-and-anomaly.
# Checks that FINOPS-REPORT.md and unit_economics.csv exist and have the
# expected shape (headers, row count, required sections).
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-17-finops}"
REPORT="$BASE/FINOPS-REPORT.md"
CSV="$BASE/unit_economics.csv"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$CSV" ]; then
  echo "FAIL: $CSV does not exist. Run compute_unit_economics.py first."
  exit 1
fi

if [ ! -f "$REPORT" ]; then
  echo "FAIL: $REPORT does not exist. Student must produce it."
  exit 1
fi

# unit_economics.csv header check.
header=$(head -n 1 "$CSV" | tr -d '\r')
expected="month,service,cost_usd,mau,requests,cost_per_mau,cost_per_req"
if [ "$header" = "$expected" ]; then
  echo "  OK   unit_economics.csv header is correct"
else
  echo "  FAIL unit_economics.csv header mismatch"
  echo "       got:      $header"
  echo "       expected: $expected"
  fail=$((fail+1))
fi

# unit_economics.csv must have at least 18 data rows (6 months x 3 services).
rows=$(($(wc -l < "$CSV") - 1))
if [ "$rows" -ge 18 ]; then
  echo "  OK   unit_economics.csv has $rows data rows (expected >=18)"
else
  echo "  FAIL unit_economics.csv has only $rows data rows (expected >=18)"
  fail=$((fail+1))
fi

# Required sections in FINOPS-REPORT.md.
if grep -qiE '^#+ *(Secci[óo]n +1|Resumen|1\. +Resumen)' "$REPORT"; then
  echo "  OK   FINOPS-REPORT.md has Resumen section"
else
  echo "  FAIL missing Resumen ejecutivo section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +2|Unit [Ee]conomics|2\. +Unit)' "$REPORT"; then
  echo "  OK   FINOPS-REPORT.md has Unit economics section"
else
  echo "  FAIL missing Unit economics section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +3|Anomal[íi]a|3\. +Anomal)' "$REPORT"; then
  echo "  OK   FINOPS-REPORT.md has Anomalia section"
else
  echo "  FAIL missing Anomalia section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +4|Acciones|4\. +Acciones)' "$REPORT"; then
  echo "  OK   FINOPS-REPORT.md has Acciones section"
else
  echo "  FAIL missing Acciones FinOps section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +5|Cost Explorer|Walkthrough|5\. +)' "$REPORT"; then
  echo "  OK   FINOPS-REPORT.md has Cost Explorer walkthrough section"
else
  echo "  FAIL missing Cost Explorer walkthrough section"
  fail=$((fail+1))
fi

# Must mention cost_per_mau and cost_per_req.
if grep -qi 'cost_per_mau\|\$/mau\|dolar.*mau' "$REPORT"; then
  echo "  OK   mentions cost_per_mau / \$/MAU"
else
  echo "  FAIL does not mention cost_per_mau / \$/MAU"
  fail=$((fail+1))
fi

if grep -qi 'cost_per_req\|\$/req\|\$/request\|dolar.*req' "$REPORT"; then
  echo "  OK   mentions cost_per_req / \$/req"
else
  echo "  FAIL does not mention cost_per_req / \$/req"
  fail=$((fail+1))
fi

# At least 5 numbered actions in the Acciones section.
actions_found=0
for n in 1 2 3 4 5; do
  if grep -Eq "^[[:space:]]*${n}\\." "$REPORT"; then
    actions_found=$((actions_found+1))
  fi
done
if [ "$actions_found" -ge 5 ]; then
  echo "  OK   FINOPS-REPORT.md has at least 5 numbered actions"
else
  echo "  FAIL FINOPS-REPORT.md has only $actions_found numbered items (expected >=5)"
  fail=$((fail+1))
fi

# Must mention at least 3 FinOps levers.
levers_found=0
for lev in "savings plan" "reserved instance" " ri " "spot" "graviton" \
           "rightsiz" "compute optimizer" "nat" "data transfer"; do
  if grep -qi "$lev" "$REPORT"; then
    levers_found=$((levers_found+1))
  fi
done
if [ "$levers_found" -ge 3 ]; then
  echo "  OK   mentions at least 3 FinOps levers ($levers_found found)"
else
  echo "  FAIL mentions only $levers_found FinOps levers (expected >=3)"
  fail=$((fail+1))
fi

# Must mention the identified anomalous month (something in 2025-05..2025-10).
if grep -qE '2025-(05|06|07|08|09|10)' "$REPORT"; then
  echo "  OK   references a specific month in the anomaly discussion"
else
  echo "  FAIL does not reference any specific month"
  fail=$((fail+1))
fi

# Must mention at least one hypothesis keyword.
if grep -qiE 'hip[óo]tesis|causa|probable|probablemente|sospech' "$REPORT"; then
  echo "  OK   discusses hypotheses / probable causes"
else
  echo "  FAIL does not discuss hypotheses / probable causes"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara FINOPS-REPORT.md con solution/REFERENCE.md para autoevaluarte."
exit 0
