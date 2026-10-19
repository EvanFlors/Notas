#!/usr/bin/env bash
# Structural validation for gl-05-02-adr-components-vs-includes.
# Checks that ADR-REUSE-STRATEGY.md exists and contains the required ADR
# sections, mentions the 3 mechanisms (extends/include/component), the 3
# scenarios (A/B/C), and includes spec:inputs:, SemVer, alternatives and
# an anti-pattern.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gl-05-02}"
DOC="$BASE/ADR-REUSE-STRATEGY.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like an ADR (title mentioning ADR).
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   ADR-REUSE-STRATEGY.md has an 'ADR' heading"
else
  echo "  FAIL ADR-REUSE-STRATEGY.md missing an 'ADR' heading"
  fail=$((fail+1))
fi

# Required ADR sections.
for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
               "Consecuencias|Consequences" "Alternativas|Alternatives"; do
  label="${section%%|*}"
  if grep -qiE "^#+ *(${section})\\b" "$DOC"; then
    echo "  OK   ADR-REUSE-STRATEGY.md has '${label}' section"
  else
    echo "  FAIL ADR-REUSE-STRATEGY.md missing '${label}' section"
    fail=$((fail+1))
  fi
done

# Must mention the three mechanisms.
if grep -qE '\bextends\b' "$DOC"; then
  echo "  OK   mentions 'extends'"
else
  echo "  FAIL does not mention 'extends'"
  fail=$((fail+1))
fi
if grep -qE '\binclude\b' "$DOC"; then
  echo "  OK   mentions 'include'"
else
  echo "  FAIL does not mention 'include'"
  fail=$((fail+1))
fi
if grep -qiE 'CI/?CD +Components?|\bcomponent\b' "$DOC"; then
  echo "  OK   mentions CI/CD Component(s)"
else
  echo "  FAIL does not mention CI/CD Component(s)"
  fail=$((fail+1))
fi

# Must mention the three scenarios (A, B, C).
scenarios=0
for s in "Escenario +A" "Escenario +B" "Escenario +C"; do
  if grep -qiE "$s" "$DOC"; then
    scenarios=$((scenarios+1))
  fi
done
if [ "$scenarios" -ge 3 ]; then
  echo "  OK   mentions all 3 scenarios (A, B, C)"
else
  echo "  FAIL mentions only ${scenarios}/3 scenarios"
  fail=$((fail+1))
fi

# Must mention spec:inputs: (contrato tipado).
if grep -qE 'spec:inputs|spec\.inputs|spec: *inputs' "$DOC" \
   || grep -qiE 'contrato +tipado|typed +contract' "$DOC"; then
  echo "  OK   mentions spec:inputs: / typed contract"
else
  echo "  FAIL does not mention spec:inputs: / typed contract"
  fail=$((fail+1))
fi

# Must mention SemVer or tag versioning.
if grep -qiE 'SemVer|Semantic +Versioning|v[0-9]+\.[0-9]+\.[0-9]+|\btag\b' "$DOC"; then
  echo "  OK   mentions SemVer / tag versioning"
else
  echo "  FAIL does not mention SemVer / tag versioning"
  fail=$((fail+1))
fi

# Must list at least 2 alternatives (subheadings or numbered items).
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
  echo "  OK   has at least 2 alternatives listed"
else
  echo "  FAIL has fewer than 2 alternatives listed (expected >=2 sub-headings or numbered items)"
  fail=$((fail+1))
fi

# Must mention at least one anti-pattern.
if grep -qiE 'anti-?patr[oó]n|anti-?pattern|include: *remote.*main|extends.*5 +niveles|sin +spec:inputs' "$DOC"; then
  echo "  OK   mentions at least one anti-pattern"
else
  echo "  FAIL does not mention any anti-pattern"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR-REUSE-STRATEGY.md con solution/REFERENCE.md para autoevaluarte."
exit 0
