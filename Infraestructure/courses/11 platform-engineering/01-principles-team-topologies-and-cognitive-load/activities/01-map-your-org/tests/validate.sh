#!/usr/bin/env bash
# Structural validation for plat-01-01-map-your-org.
# Checks that ORG_MAP.md exists and contains the required sections,
# a team table with at least 5 rows, an interactions table, an ASCII
# diagram cue, and the platform-team decision section.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-01-map}"
DOC="$BASE/ORG_MAP.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Required top-level sections (A, B, C, D).
if grep -qiE '^#+ *(Secci[óo]n +A|Equipos)' "$DOC"; then
  echo "  OK   ORG_MAP.md has Section A (Equipos)"
else
  echo "  FAIL ORG_MAP.md missing Section A / Equipos heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +B|Interacciones)' "$DOC"; then
  echo "  OK   ORG_MAP.md has Section B (Interacciones)"
else
  echo "  FAIL ORG_MAP.md missing Section B / Interacciones heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +C|Diagrama)' "$DOC"; then
  echo "  OK   ORG_MAP.md has Section C (Diagrama)"
else
  echo "  FAIL ORG_MAP.md missing Section C / Diagrama heading"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *(Secci[óo]n +D|Decisi[óo]n|Platform +team)' "$DOC"; then
  echo "  OK   ORG_MAP.md has Section D (Decision sobre platform team)"
else
  echo "  FAIL ORG_MAP.md missing Section D / Decision heading"
  fail=$((fail+1))
fi

# Tables: expect at least 11 pipe-starting lines total (header+sep+5 rows + header+sep+4 rows = 13 idealmente, pero toleramos 11).
rows=$(grep -cE '^\|' "$DOC" || true)
if [ "$rows" -ge 11 ]; then
  echo "  OK   ORG_MAP.md has at least 11 table pipe-lines ($rows found)"
else
  echo "  FAIL ORG_MAP.md has only $rows pipe-lines (expected >=11: 5 teams + 4 interactions + headers)"
  fail=$((fail+1))
fi

# Must mention at least 3 of the 4 Team Topologies team types.
types_found=0
for t in "stream-aligned" "stream aligned" "platform" "enabling" "complicated-subsystem" "complicated subsystem"; do
  if grep -qi "$t" "$DOC"; then
    types_found=$((types_found+1))
  fi
done
if [ "$types_found" -ge 3 ]; then
  echo "  OK   ORG_MAP.md names at least 3 Team Topologies team types ($types_found hits)"
else
  echo "  FAIL ORG_MAP.md names only $types_found team-type tokens (expected >=3)"
  fail=$((fail+1))
fi

# Must mention at least 2 of the 3 interaction modes.
modes_found=0
for m in "x-as-a-service" "xaas" "as-a-service" "collaboration" "collab" "facilitating" "facilit"; do
  if grep -qi "$m" "$DOC"; then
    modes_found=$((modes_found+1))
  fi
done
if [ "$modes_found" -ge 2 ]; then
  echo "  OK   ORG_MAP.md names at least 2 interaction-mode tokens ($modes_found hits)"
else
  echo "  FAIL ORG_MAP.md names only $modes_found interaction-mode tokens (expected >=2)"
  fail=$((fail+1))
fi

# Must mention X-as-a-Service specifically (because it's the default we highlight).
if grep -qiE 'x-as-a-service|xaas|as[- ]a[- ]service' "$DOC"; then
  echo "  OK   mentions X-as-a-Service explicitly"
else
  echo "  FAIL does not mention X-as-a-Service / XaaS"
  fail=$((fail+1))
fi

# Must mention Conway (either Conway's law or reverse Conway) OR cognitive load,
# as proxy that the student is thinking in Team Topologies vocabulary.
if grep -qiE 'conway|cognitive +load|carga +cognitiva' "$DOC"; then
  echo "  OK   mentions Conway or cognitive load vocabulary"
else
  echo "  FAIL does not mention Conway or cognitive load"
  fail=$((fail+1))
fi

# ASCII diagram cue: at least one line with a box character or an arrow or the
# bracket-tag convention used in the template.
if grep -qE '[│─┌└┐┘├┤┬┴┼]|-->|──►|\[S\]|\[P\]|\[E\]|\[C\]' "$DOC"; then
  echo "  OK   Section C contains ASCII diagram markers"
else
  echo "  FAIL no ASCII diagram markers found (expected box chars, arrows, or [S]/[P]/[E]/[C] tags)"
  fail=$((fail+1))
fi

# Section D must contain an explicit decision verb.
if grep -qiE 'tiene +(hoy|un|ya)|necesita|no +(lo )?(tiene|necesita)|recomiendo|decisi[óo]n' "$DOC"; then
  echo "  OK   Section D has an explicit decision verb"
else
  echo "  FAIL Section D does not express an explicit decision"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ORG_MAP.md con solution/REFERENCE.md para autoevaluarte."
exit 0
