#!/usr/bin/env bash
# Structural validation for aws-01-02-root-mfa-and-admin-user.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Checks structure, not semantics. Compare with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-01-root-mfa}"
ADR="$BASE/ADR-001-root-blindado.md"
CHK="$BASE/CHECKLIST.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$ADR" ]; then
  echo "FAIL: $ADR does not exist. Student must produce it."
  exit 1
fi
if [ ! -f "$CHK" ]; then
  echo "FAIL: $CHK does not exist. Student must produce it."
  exit 1
fi

# ---- ADR checks ----

for section in "Status" "Context" "Decision" "Alternatives" "Consequences" "Vectores de ataque" "Blast radius"; do
  if grep -qiE "^#+ *${section}" "$ADR"; then
    echo "  OK   ADR has section '${section}'"
  else
    echo "  FAIL ADR missing section '${section}'"
    fail=$((fail+1))
  fi
done

# At least 3 numbered or bulleted items under "Vectores de ataque" section.
vectors=$(awk '/^#+ *Vectores de ataque/{flag=1; next} /^#/{flag=0} flag && /^[[:space:]]*([-*]|[0-9]+\.)/{c++} END{print c+0}' "$ADR")
if [ "$vectors" -ge 3 ]; then
  echo "  OK   'Vectores de ataque' lists $vectors items (>=3)"
else
  echo "  FAIL 'Vectores de ataque' lists only $vectors items (expected >=3)"
  fail=$((fail+1))
fi

# At least 5 bullets under "Blast radius".
blast=$(awk '/^#+ *Blast radius/{flag=1; next} /^#/{flag=0} flag && /^[[:space:]]*([-*]|[0-9]+\.)/{c++} END{print c+0}' "$ADR")
if [ "$blast" -ge 5 ]; then
  echo "  OK   'Blast radius' lists $blast items (>=5)"
else
  echo "  FAIL 'Blast radius' lists only $blast items (expected >=5)"
  fail=$((fail+1))
fi

# Must mention MFA (case-insensitive).
if grep -qi 'MFA' "$ADR"; then
  echo "  OK   ADR mentions MFA"
else
  echo "  FAIL ADR does not mention MFA"
  fail=$((fail+1))
fi

# Must mention IAM Identity Center or IAM user as alternative.
if grep -qiE 'identity center|iam user' "$ADR"; then
  echo "  OK   ADR compares IAM user / Identity Center"
else
  echo "  FAIL ADR does not mention IAM user nor Identity Center"
  fail=$((fail+1))
fi

# Placeholder AccountId must be used.
if grep -q '123456789012' "$ADR"; then
  echo "  OK   ADR uses placeholder AccountId 123456789012"
else
  echo "  FAIL ADR does not use placeholder AccountId 123456789012"
  fail=$((fail+1))
fi

# ---- CHECKLIST checks ----

if grep -qE '^Ejecutado por:' "$CHK"; then
  echo "  OK   CHECKLIST signed (Ejecutado por:)"
else
  echo "  FAIL CHECKLIST missing 'Ejecutado por:' line"
  fail=$((fail+1))
fi

if grep -qE '^Fecha:' "$CHK"; then
  echo "  OK   CHECKLIST has 'Fecha:'"
else
  echo "  FAIL CHECKLIST missing 'Fecha:' line"
  fail=$((fail+1))
fi

# At least 6 checked items.
checked=$(grep -cE '^- \[x\]' "$CHK" || true)
if [ "$checked" -ge 6 ]; then
  echo "  OK   CHECKLIST has $checked checked items (>=6)"
else
  echo "  FAIL CHECKLIST has only $checked checked items (expected >=6)"
  fail=$((fail+1))
fi

# Must mention CloudTrail, Budget, MFA.
for kw in "CloudTrail" "[Bb]udget" "MFA"; do
  if grep -qE "$kw" "$CHK"; then
    echo "  OK   CHECKLIST mentions $kw"
  else
    echo "  FAIL CHECKLIST does not mention $kw"
    fail=$((fail+1))
  fi
done

# Must use placeholder AccountId.
if grep -q '123456789012' "$CHK"; then
  echo "  OK   CHECKLIST uses placeholder AccountId 123456789012"
else
  echo "  FAIL CHECKLIST does not use placeholder AccountId 123456789012"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md."
exit 0
