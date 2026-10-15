#!/usr/bin/env bash
# Structural validation for tf-01-01-draw-the-cycle.
# Checks that MAP.md exists and contains the required sections, keywords,
# cycle phases, plan symbols and 7 numbered answers.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/MAP-reference.md.

BASE="${1:-/tmp/tf-01-cycle}"
MAP="$BASE/MAP.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$MAP" ]; then
  echo "FAIL: $MAP does not exist. Student must produce it."
  exit 1
fi

# Four required sections (A/B/C/D) — accept headings in several styles.
required_sections=(
  "tres estados"
  "ciclo"
  "símbolos"
  "drift"
)
for s in "${required_sections[@]}"; do
  if grep -qi "$s" "$MAP"; then
    echo "  OK   MAP.md mentions section topic: '$s'"
  else
    echo "  FAIL MAP.md missing topic: '$s'"
    fail=$((fail+1))
  fi
done

# The 4 cycle phases must appear by name.
for phase in init plan apply destroy; do
  if grep -qiw "$phase" "$MAP"; then
    echo "  OK   mentions phase '$phase'"
  else
    echo "  FAIL does not mention phase '$phase'"
    fail=$((fail+1))
  fi
done

# refresh sub-phase.
if grep -qi "refresh" "$MAP"; then
  echo "  OK   mentions 'refresh'"
else
  echo "  FAIL does not mention 'refresh'"
  fail=$((fail+1))
fi

# Three states by name (plus "infra real" / "state" / "deseado").
for term in "deseado" "state" "real"; do
  if grep -qi "$term" "$MAP"; then
    echo "  OK   mentions state concept '$term'"
  else
    echo "  FAIL does not mention state concept '$term'"
    fail=$((fail+1))
  fi
done

# Plan symbols — at least four of these must appear verbatim.
symbols_found=0
for sym in '+' '\-' '~' '\-/+'; do
  if grep -q -- "$sym" "$MAP"; then
    symbols_found=$((symbols_found+1))
  fi
done
if [ "$symbols_found" -ge 3 ]; then
  echo "  OK   MAP.md shows at least 3 plan symbols"
else
  echo "  FAIL MAP.md shows only $symbols_found plan symbols (expected >=3)"
  fail=$((fail+1))
fi

# Idempotencia / provider mentions.
for kw in "idempoten" "provider"; do
  if grep -qi "$kw" "$MAP"; then
    echo "  OK   mentions keyword '$kw'"
  else
    echo "  FAIL does not mention keyword '$kw'"
    fail=$((fail+1))
  fi
done

# 7 numbered answers.
answers_found=0
for n in 1 2 3 4 5 6 7; do
  if grep -Eq "^(##? )?${n}\\." "$MAP"; then
    answers_found=$((answers_found+1))
  fi
done
if [ "$answers_found" -ge 7 ]; then
  echo "  OK   MAP.md answers at least 7 numbered questions"
else
  echo "  FAIL MAP.md has $answers_found numbered answers (expected >=7)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/MAP-reference.md.)"
  exit 1
fi
echo "OK: estructura válida. Compara MAP.md con solution/MAP-reference.md para autoevaluarte."
exit 0
