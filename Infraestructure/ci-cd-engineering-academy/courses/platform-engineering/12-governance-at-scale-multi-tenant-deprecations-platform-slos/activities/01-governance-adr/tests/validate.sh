#!/usr/bin/env bash
# Structural validation for plat-12-01-governance-adr.
# Checks that GOVERNANCE-ADR.md exists and contains the required ADR
# sections, decision markers, SLO and governance vocabulary.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks use
# `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep finds a
# match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-12-governance}"
DOC="$BASE/GOVERNANCE-ADR.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Section headings.
if grep -qiE '^#+ *(Secci[óo]n +1|Contexto)' "$DOC"; then
  echo "  OK   has Contexto section"
else
  echo "  FAIL missing Contexto section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ .*Consecuencias' "$DOC"; then
  echo "  OK   has Consecuencias section"
else
  echo "  FAIL missing Consecuencias section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ .*Alternativas' "$DOC"; then
  echo "  OK   has Alternativas section"
else
  echo "  FAIL missing Alternativas section"
  fail=$((fail+1))
fi

# Decision markers: at least 6 occurrences of "Decisi(o|ó)n".
decisions=$(grep -ciE 'Decisi[óo]n' "$DOC")
if [ "$decisions" -ge 6 ]; then
  echo "  OK   has at least 6 Decision markers ($decisions found)"
else
  echo "  FAIL only $decisions Decision markers (expected >=6)"
  fail=$((fail+1))
fi

# Multi-tenancy / tenant.
if grep -qiE 'multi-tenancy|tenant' "$DOC"; then
  echo "  OK   mentions multi-tenancy/tenant"
else
  echo "  FAIL does not mention multi-tenancy nor tenant"
  fail=$((fail+1))
fi

# Deprecation.
if grep -qiE 'deprecation|deprecaci' "$DOC"; then
  echo "  OK   mentions deprecation / deprecacion"
else
  echo "  FAIL does not mention deprecation"
  fail=$((fail+1))
fi

# SLO at least 3 occurrences.
slos=$(grep -coE '\bSLO\b' "$DOC")
if [ "$slos" -ge 3 ]; then
  echo "  OK   mentions SLO at least 3 times ($slos found)"
else
  echo "  FAIL only $slos mentions of SLO (expected >=3)"
  fail=$((fail+1))
fi

# Error budget / presupuesto.
if grep -qiE 'error budget|presupuesto'  "$DOC"; then
  echo "  OK   mentions error budget / presupuesto"
else
  echo "  FAIL does not mention error budget / presupuesto"
  fail=$((fail+1))
fi

# Inner-source.
if grep -qiE 'inner-source|inner source' "$DOC"; then
  echo "  OK   mentions inner-source"
else
  echo "  FAIL does not mention inner-source"
  fail=$((fail+1))
fi

# SemVer / versionado.
if grep -qiE 'semver|versionado' "$DOC"; then
  echo "  OK   mentions SemVer / versionado"
else
  echo "  FAIL does not mention SemVer / versionado"
  fail=$((fail+1))
fi

# AppProject or namespace.
if grep -qiE 'appproject|namespace' "$DOC"; then
  echo "  OK   mentions AppProject / namespace"
else
  echo "  FAIL does not mention AppProject nor namespace"
  fail=$((fail+1))
fi

# Changelog.
if grep -qi 'changelog' "$DOC"; then
  echo "  OK   mentions changelog"
else
  echo "  FAIL does not mention changelog"
  fail=$((fail+1))
fi

# scaffolder / catalog / backstage.
if grep -qiE 'scaffolder|catalog|backstage' "$DOC"; then
  echo "  OK   mentions scaffolder / catalog / backstage"
else
  echo "  FAIL does not mention scaffolder/catalog/backstage"
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
echo "OK: estructura valida. Compara GOVERNANCE-ADR.md con solution/REFERENCE.md para autoevaluarte."
exit 0
