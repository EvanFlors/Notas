#!/usr/bin/env bash
# Structural validation for tf-01-02-why-do-we-need-state.
# Checks that WRITEUP.md exists and contains the required sections, keywords
# and 7 numbered answers.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/WRITEUP-reference.md.

BASE="${1:-/tmp/tf-01-state}"
DOC="$BASE/WRITEUP.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Four required sections (A/B/C/D) — accept headings in several styles.
required_sections=(
  "razones"
  "stateless"
  "drift"
  "operativ"
)
for s in "${required_sections[@]}"; do
  if grep -qi "$s" "$DOC"; then
    echo "  OK   WRITEUP.md mentions section topic: '$s'"
  else
    echo "  FAIL WRITEUP.md missing topic: '$s'"
    fail=$((fail+1))
  fi
done

# Key terms must appear.
for kw in "state" "drift" "backend" "lock" "mape" "computad"; do
  if grep -qi "$kw" "$DOC"; then
    echo "  OK   mentions keyword '$kw'"
  else
    echo "  FAIL does not mention keyword '$kw'"
    fail=$((fail+1))
  fi
done

# Must mention Git / tfstate (for section D: why not Git).
for kw in "git" "tfstate"; do
  if grep -qi "$kw" "$DOC"; then
    echo "  OK   mentions '$kw'"
  else
    echo "  FAIL does not mention '$kw'"
    fail=$((fail+1))
  fi
done

# At least one concrete attribute example (id, arn, ip, fingerprint).
if grep -qiE 'id|arn|ip|fingerprint'  "$DOC"; then
  echo "  OK   mentions at least one computed-attribute example"
else
  echo "  FAIL does not mention any computed attribute (id/arn/ip/fingerprint)"
  fail=$((fail+1))
fi

# 7 numbered answers.
answers_found=0
for n in 1 2 3 4 5 6 7; do
  if grep -Eq "^(##? )?${n}\\." "$DOC"; then
    answers_found=$((answers_found+1))
  fi
done
if [ "$answers_found" -ge 7 ]; then
  echo "  OK   WRITEUP.md answers at least 7 numbered questions"
else
  echo "  FAIL WRITEUP.md has $answers_found numbered answers (expected >=7)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/WRITEUP-reference.md.)"
  exit 1
fi
echo "OK: estructura válida. Compara WRITEUP.md con solution/WRITEUP-reference.md para autoevaluarte."
exit 0
