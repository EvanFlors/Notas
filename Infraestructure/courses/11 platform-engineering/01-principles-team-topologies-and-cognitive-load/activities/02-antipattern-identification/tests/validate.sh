#!/usr/bin/env bash
# Structural validation for plat-01-02-antipattern-identification.
# Checks that ANTIPATTERNS.md exists and contains the required sections,
# an antipattern label per situation, corrective moves, and the synthesis
# with 6 numbered criteria.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-01-anti}"
DOC="$BASE/ANTIPATTERNS.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# All 4 situations must appear as headings.
for n in 1 2 3 4; do
  if grep -qiE "^#+ *Situaci[óo]n +${n}" "$DOC"; then
    echo "  OK   ANTIPATTERNS.md has 'Situacion ${n}' heading"
  else
    echo "  FAIL ANTIPATTERNS.md missing 'Situacion ${n}' heading"
    fail=$((fail+1))
  fi
done

# Each situation should name an antipattern.
antipattern_hits=$(grep -cEi 'antipattern|anti-pattern' "$DOC" || true)
if [ "$antipattern_hits" -ge 4 ]; then
  echo "  OK   ANTIPATTERNS.md has at least 4 'antipattern' markers ($antipattern_hits found)"
else
  echo "  FAIL ANTIPATTERNS.md has only $antipattern_hits 'antipattern' markers (expected >=4)"
  fail=$((fail+1))
fi

# Must name at least 3 distinct canonical antipattern labels.
labels_found=0
for lbl in "ivory tower" "ticketing" "dumping ground" "devops-as-role" "devops as role" \
           "product mindset" "enabling team eterno" "enabling eterno" "eternal enabling"; do
  if grep -qi "$lbl" "$DOC"; then
    labels_found=$((labels_found+1))
  fi
done
if [ "$labels_found" -ge 3 ]; then
  echo "  OK   names at least 3 canonical antipattern labels ($labels_found found)"
else
  echo "  FAIL names only $labels_found canonical antipattern labels (expected >=3)"
  fail=$((fail+1))
fi

# Must mention 'causa' (causa raiz) at least 3 times (one per situation ideally).
cause_hits=$(grep -cEi 'causa +ra[íi]z|root +cause' "$DOC" || true)
if [ "$cause_hits" -ge 3 ]; then
  echo "  OK   has at least 3 'causa raiz' markers ($cause_hits found)"
else
  echo "  FAIL has only $cause_hits 'causa raiz' markers (expected >=3)"
  fail=$((fail+1))
fi

# Must mention a corrective-move marker.
if grep -qiE 'movimiento +correctivo|correctivo|90 +d[íi]as|corrective' "$DOC"; then
  echo "  OK   mentions corrective move / 90 days"
else
  echo "  FAIL no mention of corrective move / 90 dias"
  fail=$((fail+1))
fi

# Must mention cognitive load vocabulary.
if grep -qiE 'cognitive +load|carga +cognitiva' "$DOC"; then
  echo "  OK   mentions cognitive load / carga cognitiva"
else
  echo "  FAIL no mention of cognitive load / carga cognitiva"
  fail=$((fail+1))
fi

# Must mention at least one DORA/metric vocabulary token.
if grep -qiE 'dora|lead[- ]?time|deployment +frequency|platform +nps|adopci[óo]n|mttr|change +failure' "$DOC"; then
  echo "  OK   mentions DORA / platform-metric vocabulary"
else
  echo "  FAIL no mention of DORA / platform-metric vocabulary"
  fail=$((fail+1))
fi

# Must have the Sintesis section.
if grep -qiE '^#+ *S[íi]ntesis' "$DOC"; then
  echo "  OK   has 'Sintesis' section"
else
  echo "  FAIL missing 'Sintesis' section"
  fail=$((fail+1))
fi

# Must mention 'ticket' queue specifically (synthesis topic).
if grep -qiE 'ticket' "$DOC"; then
  echo "  OK   mentions ticket queue"
else
  echo "  FAIL no mention of ticket queue"
  fail=$((fail+1))
fi

# Must have 6 numbered criteria in the synthesis (1. through 6.).
criteria_found=0
for n in 1 2 3 4 5 6; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    criteria_found=$((criteria_found+1))
  fi
done
if [ "$criteria_found" -ge 6 ]; then
  echo "  OK   has at least 6 numbered criteria"
else
  echo "  FAIL has $criteria_found numbered criteria (expected >=6)"
  fail=$((fail+1))
fi

# Must mention X-as-a-Service or self-service to show understanding of the alternative.
if grep -qiE 'x-as-a-service|xaas|self[- ]?service|as[- ]a[- ]service' "$DOC"; then
  echo "  OK   mentions X-as-a-Service / self-service as alternative"
else
  echo "  FAIL does not mention X-as-a-Service / self-service"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ANTIPATTERNS.md con solution/REFERENCE.md para autoevaluarte."
exit 0
