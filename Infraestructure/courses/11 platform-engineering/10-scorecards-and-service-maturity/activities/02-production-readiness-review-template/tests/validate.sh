#!/usr/bin/env bash
# Structural validation for plat-10-02-production-readiness-review-template.
# Checks that PRR-TEMPLATE.md and NOTES.md exist and contain the required
# sections, scorecard references, and qualitative areas.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/TEMPLATE.md.

set -eu

BASE="${1:-/tmp/plat-10-prr}"
PRR="$BASE/PRR-TEMPLATE.md"
NOTES="$BASE/NOTES.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$PRR" ]; then
  echo "FAIL: $PRR does not exist. Student must produce it."
  exit 1
fi
if [ ! -f "$NOTES" ]; then
  echo "FAIL: $NOTES does not exist. Student must produce it."
  exit 1
fi

# PRR-TEMPLATE.md must have at least 7 numbered sections (1. .. 7.).
sections_found=0
for n in 1 2 3 4 5 6 7; do
  if grep -Eq "^#+[[:space:]]*(Secci[óo]n[[:space:]]+)?${n}[\\.\\)]" "$PRR"; then
    sections_found=$((sections_found+1))
  fi
done
if [ "$sections_found" -ge 7 ]; then
  echo "  OK   PRR-TEMPLATE.md has at least 7 numbered sections ($sections_found found)"
else
  echo "  FAIL PRR-TEMPLATE.md has $sections_found numbered sections (expected >=7)"
  fail=$((fail+1))
fi

# PRR must cite 'scorecard' at least twice.
scorecard_mentions=$(grep -ci 'scorecard' "$PRR" || true)
if [ "$scorecard_mentions" -ge 2 ]; then
  echo "  OK   PRR-TEMPLATE.md cites 'scorecard' at least twice ($scorecard_mentions)"
else
  echo "  FAIL PRR-TEMPLATE.md cites 'scorecard' only $scorecard_mentions time(s) (expected >=2)"
  fail=$((fail+1))
fi

# PRR must mention 6 qualitative, non-automatable areas.
areas=0
for a in "dependencias" "dependenc" "modos de fallo" "fallo" "capacidad" "escalado" \
         "rollback" "disaster recovery" "\\bdr\\b" "on-call" "oncall" "ownership" \
         "archivo" "revisi[óo]n"; do
  if grep -qiE "$a" "$PRR"; then
    areas=$((areas+1))
  fi
done
if [ "$areas" -ge 6 ]; then
  echo "  OK   PRR-TEMPLATE.md names at least 6 qualitative areas ($areas tokens matched)"
else
  echo "  FAIL PRR-TEMPLATE.md names only $areas qualitative areas (expected >=6)"
  fail=$((fail+1))
fi

# PRR must explicitly note it does NOT replace / NOT duplicate the scorecard.
if grep -qiE 'no repite|no reemplaz|no sustituy|no duplic|cita' "$PRR"; then
  echo "  OK   PRR-TEMPLATE.md explicitly notes its relation to the scorecard"
else
  echo "  FAIL PRR-TEMPLATE.md does not explicitly disclaim duplication of scorecard"
  fail=$((fail+1))
fi

# NOTES.md must have sections A, B, C.
for sec in A B C; do
  if grep -qiE "^#+[[:space:]]*(Secci[óo]n[[:space:]]+)?${sec}([[:space:]]|$|—|\\-)" "$NOTES"; then
    echo "  OK   NOTES.md has Section $sec"
  else
    echo "  FAIL NOTES.md missing Section $sec"
    fail=$((fail+1))
  fi
done

# NOTES.md must mention both PRR and scorecard.
if grep -qi 'prr' "$NOTES" && grep -qi 'scorecard' "$NOTES"; then
  echo "  OK   NOTES.md mentions both PRR and scorecard"
else
  echo "  FAIL NOTES.md must mention both PRR and scorecard"
  fail=$((fail+1))
fi

# NOTES.md must mention a flow verb (archivo, revisi, flujo).
if grep -qiE 'flujo|archivo|revisi[óo]n' "$NOTES"; then
  echo "  OK   NOTES.md describes the archive/review flow"
else
  echo "  FAIL NOTES.md does not describe the archive/review flow"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/TEMPLATE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara PRR-TEMPLATE.md + NOTES.md con solution/TEMPLATE.md."
exit 0
