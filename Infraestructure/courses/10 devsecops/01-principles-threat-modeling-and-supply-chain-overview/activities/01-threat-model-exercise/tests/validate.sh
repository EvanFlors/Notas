#!/usr/bin/env bash
# Structural validation for sec-01-01-threat-model-exercise.
# Checks that THREAT_MODEL.md exists and contains the required sections,
# STRIDE coverage of 6 letters, trust boundaries, and assumptions.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/sec-01-threat-model}"
DOC="$BASE/THREAT_MODEL.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Section 1 — Scope
if grep -qiE '^#+ *(secci[óo]n *1|scope|alcance)' "$DOC"; then
  echo "  OK   THREAT_MODEL.md has Section 1 / Scope"
else
  echo "  FAIL THREAT_MODEL.md missing Scope section (heading with 'scope' or 'alcance')"
  fail=$((fail+1))
fi

# Section 2 — DFD
if grep -qiE '^#+ *(secci[óo]n *2|dfd|data flow|diagrama)' "$DOC"; then
  echo "  OK   THREAT_MODEL.md has Section 2 / DFD"
else
  echo "  FAIL THREAT_MODEL.md missing DFD section"
  fail=$((fail+1))
fi

# Must contain at least one fenced code block (ASCII DFD)
fences=$(grep -cE '^```' "$DOC" || true)
if [ "$fences" -ge 2 ]; then
  echo "  OK   THREAT_MODEL.md contains at least one fenced code block ($fences fences)"
else
  echo "  FAIL THREAT_MODEL.md has $fences fences (expected >=2, i.e. one block)"
  fail=$((fail+1))
fi

# Section 3 — Trust boundaries
if grep -qiE '^#+ *(secci[óo]n *3|trust boundar|l[íi]mite +de +confianza)' "$DOC"; then
  echo "  OK   THREAT_MODEL.md has Trust boundaries section"
else
  echo "  FAIL THREAT_MODEL.md missing Trust boundaries section"
  fail=$((fail+1))
fi

# Must mention 'trust boundary' or 'límite de confianza' at least twice
tb_count=$(grep -ciE 'trust +boundary|l[íi]mite +de +confianza' "$DOC" || true)
if [ "$tb_count" -ge 2 ]; then
  echo "  OK   trust boundary mentioned $tb_count times (>=2)"
else
  echo "  FAIL trust boundary mentioned only $tb_count times (expected >=2)"
  fail=$((fail+1))
fi

# Section 4 — STRIDE table
if grep -qiE '^#+ *(secci[óo]n *4|stride|amenaza|threats)' "$DOC"; then
  echo "  OK   THREAT_MODEL.md has STRIDE section"
else
  echo "  FAIL THREAT_MODEL.md missing STRIDE section"
  fail=$((fail+1))
fi

# Table must have at least 8 pipe-lines (header + sep + 6 rows)
rows=$(grep -cE '^\|' "$DOC" || true)
if [ "$rows" -ge 8 ]; then
  echo "  OK   STRIDE table has $rows pipe-lines (>=8)"
else
  echo "  FAIL STRIDE table has $rows pipe-lines (expected >=8)"
  fail=$((fail+1))
fi

# All 6 STRIDE letters must appear in the body (standalone or in tables).
# We look for the letters surrounded by non-letter boundaries OR as part of
# recognizable words (spoofing, tampering, repudiation, information,
# disclosure, denial, elevation).
missing_letters=""
# Spoofing
if ! grep -qiE 'spoofing|\| *S *\||^\s*S\s*[-|]|category.*s$' "$DOC"; then
  if ! grep -qE '\| *S *\|' "$DOC"; then missing_letters+="S "; fi
fi
# Tampering
if ! grep -qiE 'tampering' "$DOC" && ! grep -qE '\| *T *\|' "$DOC"; then
  missing_letters+="T "
fi
# Repudiation
if ! grep -qiE 'repudiation|repudio' "$DOC" && ! grep -qE '\| *R *\|' "$DOC"; then
  missing_letters+="R "
fi
# Information disclosure
if ! grep -qiE 'information|disclosure|divulgaci[óo]n' "$DOC" && ! grep -qE '\| *I *\|' "$DOC"; then
  missing_letters+="I "
fi
# Denial of service
if ! grep -qiE 'denial|dos|denegaci[óo]n' "$DOC" && ! grep -qE '\| *D *\|' "$DOC"; then
  missing_letters+="D "
fi
# Elevation of privilege
if ! grep -qiE 'elevation|elevaci[óo]n|privilege|privilegio' "$DOC" && ! grep -qE '\| *E *\|' "$DOC"; then
  missing_letters+="E "
fi

if [ -z "$missing_letters" ]; then
  echo "  OK   STRIDE covers all 6 letters (S, T, R, I, D, E)"
else
  echo "  FAIL STRIDE missing coverage for letters: $missing_letters"
  fail=$((fail+1))
fi

# Section 5 — Assumptions
if grep -qiE '^#+ *(secci[óo]n *5|assumption|suposicion|asunciones|supuestos)' "$DOC"; then
  echo "  OK   THREAT_MODEL.md has Assumptions section"
else
  echo "  FAIL THREAT_MODEL.md missing Assumptions section"
  fail=$((fail+1))
fi

# Count bullet or numbered items under any section as a proxy for 'at least 3 assumptions'.
# Heuristic: find lines starting with '- ' or '* ' or '1.' etc. The document may have
# many bullets elsewhere; we require >=3 overall and trust the student put them in.
bullets=$(grep -cE '^[[:space:]]*([-*]|[0-9]+\.) ' "$DOC" || true)
if [ "$bullets" -ge 3 ]; then
  echo "  OK   document contains $bullets bullet/numbered items (proxy for assumptions >=3)"
else
  echo "  FAIL document has only $bullets bullet/numbered items (expected >=3)"
  fail=$((fail+1))
fi

# Must mention likelihood / impact or H/M/L prioritization
if grep -qiE 'likelihood|probabilidad|impact|impacto' "$DOC"; then
  echo "  OK   mentions likelihood/impact (prioritization vocabulary)"
else
  echo "  FAIL does not mention likelihood/impact (no prioritization)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara THREAT_MODEL.md con solution/REFERENCE.md para autoevaluarte."
exit 0
