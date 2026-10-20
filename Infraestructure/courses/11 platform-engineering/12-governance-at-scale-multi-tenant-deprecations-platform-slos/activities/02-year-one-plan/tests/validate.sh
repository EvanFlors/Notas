#!/usr/bin/env bash
# Structural validation for plat-12-02-year-one-plan.
# Checks that YEAR-ONE-PLAN.md exists and contains the required quarterly
# sections, scenarios, success metrics and governance vocabulary.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks use
# `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep finds a
# match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-12-year-one}"
DOC="$BASE/YEAR-ONE-PLAN.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Q1-Q4 headings (allow "Q1" or "Trimestre 1" variants).
for q in 1 2 3 4; do
  if grep -qiE "^#+ *(Q${q}\\b|Trimestre +${q}\\b)" "$DOC"; then
    echo "  OK   has Q${q} / Trimestre ${q} heading"
  else
    echo "  FAIL missing Q${q} / Trimestre ${q} heading"
    fail=$((fail+1))
  fi
done

# Escenarios section.
if grep -qiE '^#+ *Escenarios' "$DOC"; then
  echo "  OK   has Escenarios section"
else
  echo "  FAIL missing Escenarios section"
  fail=$((fail+1))
fi

# The 3 scenario names.
if grep -qiE 'crecimiento|r[áa]pido' "$DOC"; then
  echo "  OK   mentions crecimiento rapido scenario"
else
  echo "  FAIL does not mention crecimiento / rapido scenario"
  fail=$((fail+1))
fi

if grep -qiE 'hiring[- ]?freeze|hiring' "$DOC"; then
  echo "  OK   mentions hiring freeze scenario"
else
  echo "  FAIL does not mention hiring freeze"
  fail=$((fail+1))
fi

if grep -qiE 'merger|consolidaci' "$DOC"; then
  echo "  OK   mentions merger / consolidacion scenario"
else
  echo "  FAIL does not mention merger / consolidacion"
  fail=$((fail+1))
fi

# SLO at least 2 occurrences.
slos=$(grep -coE '\bSLO\b' "$DOC")
if [ "$slos" -ge 2 ]; then
  echo "  OK   mentions SLO at least 2 times ($slos found)"
else
  echo "  FAIL only $slos mentions of SLO (expected >=2)"
  fail=$((fail+1))
fi

# DORA.
if grep -qi 'DORA' "$DOC"; then
  echo "  OK   mentions DORA"
else
  echo "  FAIL does not mention DORA"
  fail=$((fail+1))
fi

# roadmap.
if grep -qi 'roadmap' "$DOC"; then
  echo "  OK   mentions roadmap"
else
  echo "  FAIL does not mention roadmap"
  fail=$((fail+1))
fi

# platform.
if grep -qi 'platform' "$DOC"; then
  echo "  OK   mentions platform"
else
  echo "  FAIL does not mention platform"
  fail=$((fail+1))
fi

# scorecard OR adopcion.
if grep -qiE 'scorecard|adopci' "$DOC"; then
  echo "  OK   mentions scorecard / adopcion"
else
  echo "  FAIL does not mention scorecard nor adopcion"
  fail=$((fail+1))
fi

# Metricas section.
if grep -qiE '^#+ *M[ée]tricas|^#+ *Metrics' "$DOC"; then
  echo "  OK   has Metricas / Metrics section"
else
  echo "  FAIL missing Metricas / Metrics section"
  fail=$((fail+1))
fi

# At least 4 numbered items (1. 2. 3. 4.).
items_found=0
for n in 1 2 3 4; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    items_found=$((items_found+1))
  fi
done
if [ "$items_found" -ge 4 ]; then
  echo "  OK   has at least 4 numbered items"
else
  echo "  FAIL only $items_found numbered items (expected >=4)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara YEAR-ONE-PLAN.md con solution/REFERENCE.md para autoevaluarte."
exit 0
