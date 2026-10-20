#!/usr/bin/env bash
# Structural validation for plat-03-01-tool-choice-adr.
# Checks that ADR.md exists and contains the required sections (Context,
# Decision, Alternatives, Consequences, Follow-ups), the mandatory
# vocabulary (TCO, vendor/lock-in, at least 2 non-technical criteria),
# and references at least 4 of the 6 landscape tools.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-03-adr}"
DOC="$BASE/ADR.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Required ADR sections.
if grep -qiE '^#+ *Status\b' "$DOC"; then
  echo "  OK   ADR.md has Status section"
else
  echo "  FAIL ADR.md missing Status section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *Context\b' "$DOC"; then
  echo "  OK   ADR.md has Context section"
else
  echo "  FAIL ADR.md missing Context section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *Decision\b' "$DOC"; then
  echo "  OK   ADR.md has Decision section"
else
  echo "  FAIL ADR.md missing Decision section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *Alternatives?\b' "$DOC"; then
  echo "  OK   ADR.md has Alternatives section"
else
  echo "  FAIL ADR.md missing Alternatives section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *Consequences?\b' "$DOC"; then
  echo "  OK   ADR.md has Consequences section"
else
  echo "  FAIL ADR.md missing Consequences section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *Follow[- ]?ups?\b' "$DOC"; then
  echo "  OK   ADR.md has Follow-ups section"
else
  echo "  FAIL ADR.md missing Follow-ups section"
  fail=$((fail+1))
fi

# Must name at least 4 of the 6 landscape tools.
tools=0
for t in "backstage" "port" "opslevel" "cortex" "humanitec" "cnoe"; do
  if grep -qi "\b${t}\b" "$DOC"; then
    tools=$((tools+1))
  fi
done
if [ "$tools" -ge 4 ]; then
  echo "  OK   ADR.md names at least 4 landscape tools ($tools found)"
else
  echo "  FAIL ADR.md names only $tools landscape tools (expected >=4)"
  fail=$((fail+1))
fi

# Must mention TCO or coste total / capex / opex.
if grep -qiE '\btco\b|coste total|costo total|capex|opex' "$DOC"; then
  echo "  OK   mentions TCO / capex / opex"
else
  echo "  FAIL does not mention TCO, capex nor opex"
  fail=$((fail+1))
fi

# Must mention vendor or lock-in.
if grep -qiE 'vendor|lock[- ]?in'  "$DOC"; then
  echo "  OK   mentions vendor / lock-in"
else
  echo "  FAIL does not mention vendor nor lock-in"
  fail=$((fail+1))
fi

# Must mention at least 2 non-technical criteria from a canonical list.
nt_found=0
for crit in "presupuesto" "budget" "hiring" "adopci" "financia" \
            "deprecation" "compliance" "tama[ñn]o del equipo" "equipo plataforma"; do
  if grep -qi "$crit" "$DOC"; then
    nt_found=$((nt_found+1))
  fi
done
if [ "$nt_found" -ge 2 ]; then
  echo "  OK   ADR.md mentions at least 2 non-technical criteria ($nt_found found)"
else
  echo "  FAIL ADR.md mentions only $nt_found non-technical criteria (expected >=2)"
  fail=$((fail+1))
fi

# Must have at least 3 bullets / lines inside Alternatives (proxy: look for
# at least 3 bulleted lines after the Alternatives heading).
alt_bullets=$(awk '
  BEGIN{in_section=0; count=0}
  /^#+ *[Aa]lternatives?/{in_section=1; next}
  /^#+ /{if (in_section) exit; in_section=0}
  in_section && /^[[:space:]]*[-*][[:space:]]/{count++}
  END{print count}
' "$DOC")
if [ "$alt_bullets" -ge 3 ]; then
  echo "  OK   Alternatives section has at least 3 bulleted items ($alt_bullets found)"
else
  echo "  FAIL Alternatives section has only $alt_bullets bulleted items (expected >=3)"
  fail=$((fail+1))
fi

# Must mention Negativas / negative consequences accepted.
if grep -qiE 'negativas?|negative|accepted|aceptadas?' "$DOC"; then
  echo "  OK   mentions negative/accepted consequences"
else
  echo "  FAIL does not mention negative/accepted consequences"
  fail=$((fail+1))
fi

# Follow-ups must contain at least 1 bullet mentioning an owner marker
# (dueno/dueño/owner/responsable/lead) and a time horizon (dias/semanas/meses/days/weeks/months).
if grep -qiE 'due[nñ]o|owner|responsable|lead' "$DOC" \
   && grep -qiE '\b(d[ií]as?|semanas?|meses?|days?|weeks?|months?|q[1-4]|trimestr)\b' "$DOC"; then
  echo "  OK   contains owner markers and time horizons"
else
  echo "  FAIL missing owner markers or time horizons in follow-ups"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR.md con solution/REFERENCE.md para autoevaluarte."
exit 0
