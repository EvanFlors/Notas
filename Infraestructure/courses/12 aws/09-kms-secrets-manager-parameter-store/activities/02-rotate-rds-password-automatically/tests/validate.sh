#!/usr/bin/env bash
# Structural validation for aws-09-02-rotate-rds-password-automatically.
# Checks that ROTATION.md exists and has the required sections, keywords
# and 5 classification rows.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-09-rotate-rds}"
DOC="$BASE/ROTATION.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# ---- 6 required section headings (A..F) ----
for sec in "A" "B" "C" "D" "E" "F"; do
  if grep -qE "^#+ *Secci[óo]n +${sec}\\b" "$DOC"; then
    echo "  OK   ROTATION.md has Section $sec"
  else
    echo "  FAIL ROTATION.md missing Section $sec"
    fail=$((fail+1))
  fi
done

# ---- Section A: diagram cues ----
if grep -qiE 'rotator' "$DOC" && grep -qiE 'rds' "$DOC" && grep -qiE 'secret' "$DOC"; then
  echo "  OK   mentions rotator, rds, secret (Section A cues)"
else
  echo "  FAIL missing diagram cues (rotator / rds / secret)"
  fail=$((fail+1))
fi

# ---- Section B: 4 step names must appear literally ----
for step in createSecret setSecret testSecret finishSecret; do
  if grep -q "$step" "$DOC"; then
    echo "  OK   mentions step: $step"
  else
    echo "  FAIL missing step name: $step"
    fail=$((fail+1))
  fi
done

# ---- Section C: at least 1 json code block + required actions ----
json_fences=$(grep -cE '^```json' "$DOC")
if [ "$json_fences" -ge 1 ]; then
  echo "  OK   has at least 1 json code block ($json_fences found)"
else
  echo "  FAIL no \`\`\`json code block found"
  fail=$((fail+1))
fi
if grep -qE 'kms:Decrypt' "$DOC"; then
  echo "  OK   mentions kms:Decrypt"
else
  echo "  FAIL missing kms:Decrypt"
  fail=$((fail+1))
fi
if grep -qE 'secretsmanager:GetSecretValue' "$DOC"; then
  echo "  OK   mentions secretsmanager:GetSecretValue"
else
  echo "  FAIL missing secretsmanager:GetSecretValue"
  fail=$((fail+1))
fi

# ---- Section D: single-user and multi-user mentioned ----
if grep -qE 'single-user' "$DOC"; then
  echo "  OK   mentions single-user"
else
  echo "  FAIL missing 'single-user'"
  fail=$((fail+1))
fi
if grep -qE 'multi-user' "$DOC"; then
  echo "  OK   mentions multi-user"
else
  echo "  FAIL missing 'multi-user'"
  fail=$((fail+1))
fi

# ---- Section E: AWSPENDING and AWSPREVIOUS ----
if grep -q 'AWSPENDING' "$DOC"; then
  echo "  OK   mentions AWSPENDING"
else
  echo "  FAIL missing AWSPENDING"
  fail=$((fail+1))
fi
if grep -q 'AWSPREVIOUS' "$DOC"; then
  echo "  OK   mentions AWSPREVIOUS"
else
  echo "  FAIL missing AWSPREVIOUS"
  fail=$((fail+1))
fi

# ---- Section F: at least 5 classification rows (table rows with 1..5 markers) ----
rows=0
for n in 1 2 3 4 5; do
  if grep -qE "^\\| *${n} *\\|" "$DOC"; then
    rows=$((rows+1))
  fi
done
if [ "$rows" -ge 5 ]; then
  echo "  OK   Section F has $rows numbered rows"
else
  echo "  FAIL Section F has only $rows numbered rows (expected >=5)"
  fail=$((fail+1))
fi

# ---- Section F: must use the categories ----
cats=0
for cat in SecretsManager ParameterStore; do
  if grep -q "$cat" "$DOC"; then
    cats=$((cats+1))
  fi
done
if [ "$cats" -ge 2 ]; then
  echo "  OK   Section F uses both SecretsManager and ParameterStore categories"
else
  echo "  FAIL Section F must use both 'SecretsManager' and 'ParameterStore' as categories"
  fail=$((fail+1))
fi

# ---- Section F: at least one justification keyword ----
if grep -qiE 'rotacion|rotación|tamano|tamaño|costo|visibilidad|compartido' "$DOC"; then
  echo "  OK   uses justification vocabulary"
else
  echo "  FAIL missing justification keywords (rotacion/tamano/costo/visibilidad/compartido)"
  fail=$((fail+1))
fi

# ---- No real secrets: hint-only lint (require explicit fake labels) ----
if grep -qE 'fake-|NOT-REAL|example' "$DOC"; then
  echo "  OK   values appear labelled as fake"
else
  echo "  FAIL no 'fake-' / 'NOT-REAL' / 'example' labels found — add them"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ROTATION.md con solution/REFERENCE.md para autoevaluarte."
exit 0
