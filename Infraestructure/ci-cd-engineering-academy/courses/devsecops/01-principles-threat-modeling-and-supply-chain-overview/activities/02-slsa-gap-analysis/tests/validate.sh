#!/usr/bin/env bash
# Structural validation for sec-01-02-slsa-gap-analysis.
# Checks that SLSA_GAP.md exists and contains the 6 required sections,
# the SLSA level classification, the gap table, SBOM vs provenance,
# roadmap entries, and at least 2 named incidents.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/sec-01-slsa-gap}"
DOC="$BASE/SLSA_GAP.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Section 1 — Current state
if grep -qiE '^#+ *(secci[óo]n *1|estado +actual|current +state)' "$DOC"; then
  echo "  OK   has Section 1 / Estado actual"
else
  echo "  FAIL missing Section 1 / Estado actual"
  fail=$((fail+1))
fi

# Must mention a SLSA level (L0/L1/L2/L3 or 'nivel 0'..'nivel 3')
if grep -qiE '\bL[0-3]\b|nivel +[0-3]|slsa +[0-3]' "$DOC"; then
  echo "  OK   mentions SLSA level (L0/L1/L2/L3 or nivel N)"
else
  echo "  FAIL does not mention SLSA level L0/L1/L2/L3"
  fail=$((fail+1))
fi

# Section 2 — Objective
if grep -qiE '^#+ *(secci[óo]n *2|objetivo|target|nivel +objetivo)' "$DOC"; then
  echo "  OK   has Section 2 / Objetivo"
else
  echo "  FAIL missing Section 2 / Objetivo"
  fail=$((fail+1))
fi

# Section 3 — Gaps
if grep -qiE '^#+ *(secci[óo]n *3|gaps?|brechas)' "$DOC"; then
  echo "  OK   has Section 3 / Gaps"
else
  echo "  FAIL missing Section 3 / Gaps"
  fail=$((fail+1))
fi

# Gap table must have at least 5 pipe-lines (header + sep + 3 rows)
rows=$(grep -cE '^\|' "$DOC" || true)
if [ "$rows" -ge 5 ]; then
  echo "  OK   gap table has $rows pipe-lines (>=5 — header+sep+3 rows)"
else
  echo "  FAIL gap table has $rows pipe-lines (expected >=5)"
  fail=$((fail+1))
fi

# Section 4 — SBOM vs provenance
if grep -qiE '^#+ *(secci[óo]n *4|sbom|provenance|provenien)' "$DOC"; then
  echo "  OK   has Section 4 / SBOM vs provenance"
else
  echo "  FAIL missing Section 4 / SBOM vs provenance"
  fail=$((fail+1))
fi

# Must mention both SBOM and provenance
if grep -qi 'sbom' "$DOC"; then
  echo "  OK   mentions SBOM"
else
  echo "  FAIL does not mention SBOM"
  fail=$((fail+1))
fi
if grep -qiE 'provenance|provenien' "$DOC"; then
  echo "  OK   mentions provenance"
else
  echo "  FAIL does not mention provenance"
  fail=$((fail+1))
fi

# Section 5 — Roadmap
if grep -qiE '^#+ *(secci[óo]n *5|roadmap|plan)' "$DOC"; then
  echo "  OK   has Section 5 / Roadmap"
else
  echo "  FAIL missing Section 5 / Roadmap"
  fail=$((fail+1))
fi

# Must mention effort markers (H/M/L or alto/medio/bajo)
if grep -qiE '\b[HML]\b|alto|medio|bajo|high|medium|low' "$DOC"; then
  echo "  OK   uses effort markers (H/M/L or alto/medio/bajo)"
else
  echo "  FAIL does not mark effort (H/M/L or alto/medio/bajo)"
  fail=$((fail+1))
fi

# Section 6 — Incidents
if grep -qiE '^#+ *(secci[óo]n *6|incident|supply)' "$DOC"; then
  echo "  OK   has Section 6 / Incidentes"
else
  echo "  FAIL missing Section 6 / Incidentes"
  fail=$((fail+1))
fi

# Must mention at least 2 of SolarWinds, log4shell, xz-utils, tj-actions.
incidents=0
for inc in "solarwinds" "log4shell" "log4j" "xz-utils" "xz" "tj-actions"; do
  if grep -qi "$inc" "$DOC"; then
    incidents=$((incidents+1))
  fi
done
# log4j and log4shell could double-count; collapse to >=2 distinct keywords
if [ "$incidents" -ge 2 ]; then
  echo "  OK   names at least 2 supply-chain incidents ($incidents keywords found)"
else
  echo "  FAIL names only $incidents supply-chain incident keywords (expected >=2)"
  fail=$((fail+1))
fi

# Bullet / numbered items count — proxy for 'roadmap has >=4 items'.
bullets=$(grep -cE '^[[:space:]]*([-*]|[0-9]+\.) ' "$DOC" || true)
if [ "$bullets" -ge 4 ]; then
  echo "  OK   document contains $bullets bullet/numbered items (proxy for roadmap items >=4)"
else
  echo "  FAIL document has only $bullets bullet/numbered items (expected >=4)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara SLSA_GAP.md con solution/REFERENCE.md para autoevaluarte."
exit 0
