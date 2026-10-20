#!/usr/bin/env bash
# Structural validation for argo-01-01-identify-gitops-washing.
# Checks that MAP.md exists and contains the 4 OpenGitOps principles,
# the 5 scenarios named explicitly, references to key concepts (Argo CD,
# webhook, drift, reconciliation) and 7 numbered answers.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/MAP-reference.md.

BASE="${1:-/tmp/argo-01-washing}"
DOC="$BASE/MAP.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# 4 OpenGitOps principles must appear (English keywords in canonical form).
for p in "declarative" "versioned" "pull" "reconcil"; do
  if grep -qi "$p" "$DOC"; then
    echo "  OK   MAP.md mentions principle keyword: '$p'"
  else
    echo "  FAIL MAP.md missing principle keyword: '$p'"
    fail=$((fail+1))
  fi
done

# 5 scenarios must be named explicitly (A..E).
for s in "Escenario A" "Escenario B" "Escenario C" "Escenario D" "Escenario E"; do
  if grep -q "$s" "$DOC"; then
    echo "  OK   MAP.md references '$s'"
  else
    echo "  FAIL MAP.md does not reference '$s'"
    fail=$((fail+1))
  fi
done

# Must mention Argo CD (the tool shows up in several scenarios).
if grep -qiE 'argo[- ]?cd|argocd' "$DOC"; then
  echo "  OK   mentions Argo CD"
else
  echo "  FAIL does not mention Argo CD"
  fail=$((fail+1))
fi

# Must mention drift (central consequence to recognize).
if grep -qi "drift" "$DOC"; then
  echo "  OK   mentions drift"
else
  echo "  FAIL does not mention drift"
  fail=$((fail+1))
fi

# Must mention push vs pull dynamic (kubectl apply or push/pull terms).
if grep -qiE 'kubectl apply|push|pull' "$DOC"; then
  echo "  OK   mentions apply/push/pull dynamic"
else
  echo "  FAIL does not mention apply/push/pull dynamic"
  fail=$((fail+1))
fi

# Must mention 'washing' as the concept under audit.
if grep -qi "washing" "$DOC"; then
  echo "  OK   mentions 'washing' concept"
else
  echo "  FAIL does not mention 'washing' concept"
  fail=$((fail+1))
fi

# Must mention verdict / veredicto for scenarios.
if grep -qiE 'veredicto|verdict' "$DOC"; then
  echo "  OK   mentions veredicto/verdict"
else
  echo "  FAIL does not mention veredicto/verdict"
  fail=$((fail+1))
fi

# Must mention correction / correccion for the minimal fix per scenario.
if grep -qiE 'correcci|correction|fix' "$DOC"; then
  echo "  OK   mentions correccion/correction"
else
  echo "  FAIL does not mention correccion/correction"
  fail=$((fail+1))
fi

# At least 5 numbered items (principles 1..4 + answers 1..7 → many).
numbered_lines=$(grep -cE '^[[:space:]]*[1-9]\.' "$DOC")
if [ "$numbered_lines" -ge 5 ]; then
  echo "  OK   MAP.md contains $numbered_lines numbered items"
else
  echo "  FAIL MAP.md contains only $numbered_lines numbered items (expected >=5)"
  fail=$((fail+1))
fi

# 7 numbered answers (preguntas obligatorias) — look for 1. through 7.
answers_found=0
for n in 1 2 3 4 5 6 7; do
  if grep -Eq "^(##? )?${n}\\." "$DOC"; then
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
echo "OK: estructura valida. Compara MAP.md con solution/MAP-reference.md para autoevaluarte."
exit 0
