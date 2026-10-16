#!/usr/bin/env bash
# Structural validation for sec-08-02-slsa-level-roadmap.
# Checks that SLSA-ROADMAP.md exists and has the five sections (A..E),
# at least 5 numbered items in the claims section, and references to SLSA
# levels + attestation vocabulary.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which produces SIGPIPE (exit 141) when grep finds
# a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.
set -eu

BASE="${1:-/tmp/sec-08-roadmap}"
DOC="${BASE}/SLSA-ROADMAP.md"
fail=0

echo "== Structural validation for ${BASE} =="

if [ ! -f "${DOC}" ]; then
  echo "FAIL: ${DOC} does not exist. Student must produce it."
  exit 1
fi

# Section A — diagnostico
if grep -qiE '^#+ *(Secci[óo]n +A|Diagn[óo]stico)' "${DOC}"; then
  echo "  OK   has Section A (Diagnostico)"
else
  echo "  FAIL missing Section A / Diagnostico"
  fail=$((fail+1))
fi

# Section B — camino a L2
if grep -qiE '^#+ *(Secci[óo]n +B|Camino +a +L2|L2)' "${DOC}"; then
  echo "  OK   has Section B (Camino a L2)"
else
  echo "  FAIL missing Section B / Camino a L2"
  fail=$((fail+1))
fi

# Section C — a L3
if grep -qiE '^#+ *(Secci[óo]n +C|L3)' "${DOC}"; then
  echo "  OK   has Section C (Camino a L3)"
else
  echo "  FAIL missing Section C / Camino a L3"
  fail=$((fail+1))
fi

# Section D — metricas
if grep -qiE '^#+ *(Secci[óo]n +D|M[eé]tricas)' "${DOC}"; then
  echo "  OK   has Section D (Metricas)"
else
  echo "  FAIL missing Section D / Metricas"
  fail=$((fail+1))
fi

# Section E — afirmaciones
if grep -qiE '^#+ *(Secci[óo]n +E|Afirmaciones)' "${DOC}"; then
  echo "  OK   has Section E (Afirmaciones)"
else
  echo "  FAIL missing Section E / Afirmaciones"
  fail=$((fail+1))
fi

# Must mention SLSA
if grep -qi 'slsa' "${DOC}"; then
  echo "  OK   mentions SLSA"
else
  echo "  FAIL does not mention SLSA"
  fail=$((fail+1))
fi

# Must mention provenance or attestation
if grep -qiE 'provenance|attestation|attest-build-provenance'  "${DOC}"; then
  echo "  OK   mentions provenance/attestation"
else
  echo "  FAIL does not mention provenance nor attestation"
  fail=$((fail+1))
fi

# Must mention GitHub Actions or hosted builder
if grep -qiE 'github actions|hosted builder|gha|actions/attest'  "${DOC}"; then
  echo "  OK   mentions GitHub Actions / hosted builder"
else
  echo "  FAIL does not mention GHA / hosted builder"
  fail=$((fail+1))
fi

# Section E: at least 5 numbered claims (1. .. 5.)
claims_found=0
for n in 1 2 3 4 5; do
  if grep -Eq "^[[:space:]]*${n}\\." "${DOC}"; then
    claims_found=$((claims_found+1))
  fi
done
if [ "${claims_found}" -ge 5 ]; then
  echo "  OK   has at least 5 numbered items (${claims_found})"
else
  echo "  FAIL has ${claims_found} numbered items (expected >=5)"
  fail=$((fail+1))
fi

# At least 5 bullet lines (- or *) — proxy for the metrics + changes lists
bullets=$(grep -cE '^[[:space:]]*[-*][[:space:]]' "${DOC}" || true)
if [ "${bullets}" -ge 5 ]; then
  echo "  OK   has at least 5 bullet lines (${bullets})"
else
  echo "  FAIL has only ${bullets} bullet lines (expected >=5)"
  fail=$((fail+1))
fi

echo
if [ "${fail}" -gt 0 ]; then
  echo "RESULT: ${fail} structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara SLSA-ROADMAP.md con solution/REFERENCE.md para autoevaluarte."
exit 0
