#!/usr/bin/env bash
# Structural validation for plat-03-02-poc-matrix-for-your-org.
# Checks that POC-MATRIX.md exists and contains the required 5 sections
# (A context, B finalists, C weighted matrix, D scenarios, E plan),
# a matrix with >=8 rows, a plan with weeks and owners, and the
# vocabulary of weighted evaluation.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-03-poc}"
DOC="$BASE/POC-MATRIX.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Required 5 sections (A..E).
if grep -qiE '^#+ *(Secci[óo]n +A|Contexto)' "$DOC"; then
  echo "  OK   has Section A (Contexto)"
else
  echo "  FAIL missing Section A / Contexto heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +B|Finalistas?)' "$DOC"; then
  echo "  OK   has Section B (Finalistas)"
else
  echo "  FAIL missing Section B / Finalistas heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +C|Matriz|Criterios)' "$DOC"; then
  echo "  OK   has Section C (Matriz / Criterios)"
else
  echo "  FAIL missing Section C / Matriz heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +D|Escenarios?)' "$DOC"; then
  echo "  OK   has Section D (Escenarios)"
else
  echo "  FAIL missing Section D / Escenarios heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +E|Plan|Cronograma|Go.?No.?Go)' "$DOC"; then
  echo "  OK   has Section E (Plan / Cronograma)"
else
  echo "  FAIL missing Section E / Plan heading"
  fail=$((fail+1))
fi

# Matrix must have >=10 pipe-lines (header + separator + >=8 criteria rows).
rows=$(grep -cE '^\|' "$DOC")
if [ "$rows" -ge 10 ]; then
  echo "  OK   POC-MATRIX.md has at least 8 criteria rows ($rows pipe-lines found)"
else
  echo "  FAIL POC-MATRIX.md has only $rows pipe-lines (expected >=10)"
  fail=$((fail+1))
fi

# Must mention weight / peso / ponderad.
if grep -qiE 'peso|weight|ponderad'  "$DOC"; then
  echo "  OK   mentions peso/weight/ponderado"
else
  echo "  FAIL does not mention peso/weight/ponderado"
  fail=$((fail+1))
fi

# Must mention 100 (sum of weights) somewhere.
if grep -qE '\b100\b' "$DOC"; then
  echo "  OK   references 100 (expected weight total)"
else
  echo "  FAIL does not reference 100 anywhere (weights must sum 100)"
  fail=$((fail+1))
fi

# Must mention metrica / measurable / metric.
if grep -qiE 'm[eé]trica|measurable|medible|metric\b' "$DOC"; then
  echo "  OK   mentions metrica/medible"
else
  echo "  FAIL does not mention metrica/medible"
  fail=$((fail+1))
fi

# At least 3 scenario headings (Escenario 1..3).
scen_found=0
for n in 1 2 3; do
  if grep -qiE "^#+ *Escenario +${n}\b" "$DOC"; then
    scen_found=$((scen_found+1))
  fi
done
if [ "$scen_found" -ge 3 ]; then
  echo "  OK   at least 3 Escenario headings"
else
  echo "  FAIL only $scen_found Escenario headings (expected >=3)"
  fail=$((fail+1))
fi

# Plan must mention semanas/weeks (cronograma 2-4 weeks).
if grep -qiE '\bsemanas?\b|\bweeks?\b|semana +[1-4]|week +[1-4]' "$DOC"; then
  echo "  OK   plan mentions semanas/weeks"
else
  echo "  FAIL plan does not mention semanas/weeks"
  fail=$((fail+1))
fi

# Must mention responsible / owner / dueno.
if grep -qiE 'responsabl|due[nñ]o|owner|lead|platform team' "$DOC"; then
  echo "  OK   mentions responsables/owners"
else
  echo "  FAIL does not mention responsables/owners"
  fail=$((fail+1))
fi

# Must mention at least 4 of the 6 landscape tools.
tools=0
for t in "backstage" "port" "opslevel" "cortex" "humanitec" "cnoe"; do
  if grep -qi "\b${t}\b" "$DOC"; then
    tools=$((tools+1))
  fi
done
if [ "$tools" -ge 4 ]; then
  echo "  OK   POC-MATRIX.md references at least 4 landscape tools ($tools found)"
else
  echo "  FAIL POC-MATRIX.md references only $tools landscape tools (expected >=4)"
  fail=$((fail+1))
fi

# Must mention go/no-go decision framework.
if grep -qiE 'go.?no.?go|decision framework|tie[- ]?break' "$DOC"; then
  echo "  OK   mentions go/no-go or decision framework"
else
  echo "  FAIL does not mention go/no-go nor decision framework"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara POC-MATRIX.md con solution/REFERENCE.md para autoevaluarte."
exit 0
