#!/usr/bin/env bash
# Structural validation for plat-07-02-docs-minimum-standard-adr.
# Checks that STANDARD.md exists with the required ADR sections, a 5+ row
# artifacts table, and the key vocabulary (TechDocs, techdocs-ref, CODEOWNERS,
# in-situ or centralized, antipattern).
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# use `grep -q` with pipes that may close early (SIGPIPE / exit 141); pipefail
# would spuriously mark those as failures.
#
# Does NOT grade semantic quality — compare manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-07-standard}"
DOC="$BASE/STANDARD.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# ---------------------------------------------------------------------------
# ADR core sections
# ---------------------------------------------------------------------------
if grep -qiE '^#+ *status' "$DOC"; then
  echo "  OK   STANDARD.md has Status section"
else
  echo "  FAIL STANDARD.md missing Status section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(context|contexto)' "$DOC"; then
  echo "  OK   STANDARD.md has Context section"
else
  echo "  FAIL STANDARD.md missing Context section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(decision|decisi[óo]n)' "$DOC"; then
  echo "  OK   STANDARD.md has Decision section"
else
  echo "  FAIL STANDARD.md missing Decision section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(consequence|consecuencia)' "$DOC"; then
  echo "  OK   STANDARD.md has Consequences section"
else
  echo "  FAIL STANDARD.md missing Consequences section"
  fail=$((fail+1))
fi

# ---------------------------------------------------------------------------
# Artifacts table (>= 5 rows + header + separator → >= 7 pipe-lines)
# ---------------------------------------------------------------------------
rows=$(grep -cE '^\|' "$DOC")
if [ "$rows" -ge 7 ]; then
  echo "  OK   STANDARD.md has table with at least 5 rows ($rows pipe-lines)"
else
  echo "  FAIL STANDARD.md table has only $rows pipe-lines (expected >=7 for 5 artifact rows)"
  fail=$((fail+1))
fi

# ---------------------------------------------------------------------------
# Required artifact mentions
# ---------------------------------------------------------------------------
artifacts_found=0
for a in "readme" "index" "adr" "runbook" "api" "contact" "slo"; do
  if grep -qi "$a" "$DOC"; then
    artifacts_found=$((artifacts_found+1))
  fi
done
if [ "$artifacts_found" -ge 5 ]; then
  echo "  OK   STANDARD.md names at least 5 canonical artifacts ($artifacts_found)"
else
  echo "  FAIL STANDARD.md names only $artifacts_found canonical artifacts (expected >=5)"
  fail=$((fail+1))
fi

# ---------------------------------------------------------------------------
# Required vocabulary
# ---------------------------------------------------------------------------
if grep -qiE 'techdocs' "$DOC"; then
  echo "  OK   mentions TechDocs"
else
  echo "  FAIL does not mention TechDocs"
  fail=$((fail+1))
fi

if grep -qiE 'techdocs-ref|backstage\.io/techdocs-ref' "$DOC"; then
  echo "  OK   mentions techdocs-ref annotation"
else
  echo "  FAIL does not mention techdocs-ref annotation"
  fail=$((fail+1))
fi

if grep -qiE 'codeowners' "$DOC"; then
  echo "  OK   mentions CODEOWNERS"
else
  echo "  FAIL does not mention CODEOWNERS"
  fail=$((fail+1))
fi

if grep -qiE 'in-situ|centralized|centralizad' "$DOC"; then
  echo "  OK   mentions in-situ or centralized mode"
else
  echo "  FAIL does not mention in-situ nor centralized mode"
  fail=$((fail+1))
fi

if grep -qiE 'owner' "$DOC"; then
  echo "  OK   mentions owner / ownership"
else
  echo "  FAIL does not mention owner / ownership"
  fail=$((fail+1))
fi

# Enforcement vocabulary (soft fail / warning / bloqueo / block)
if grep -qiE 'soft fail|warning|block|bloqueo|enforce|waiver' "$DOC"; then
  echo "  OK   mentions enforcement vocabulary (soft fail / warning / block / waiver)"
else
  echo "  FAIL does not mention enforcement vocabulary"
  fail=$((fail+1))
fi

# Antipatterns section/mention
if grep -qiE 'antipattern|anti-pattern|antipatr[óo]n' "$DOC"; then
  echo "  OK   mentions antipatterns"
else
  echo "  FAIL does not mention antipatterns"
  fail=$((fail+1))
fi

# Alternatives considered
if grep -qiE 'alternativ' "$DOC"; then
  echo "  OK   mentions alternatives considered"
else
  echo "  FAIL does not mention alternatives considered"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic quality is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara STANDARD.md con solution/REFERENCE.md para autoevaluarte."
exit 0
