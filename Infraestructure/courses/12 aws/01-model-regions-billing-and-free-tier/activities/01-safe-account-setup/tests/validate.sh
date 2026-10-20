#!/usr/bin/env bash
# Structural validation for aws-01-01-safe-account-setup.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Checks structure, not semantics. Compare with solution/TEMPLATE.md.

set -eu

BASE="${1:-/tmp/aws-01-setup}"
SETUP="$BASE/ACCOUNT-SETUP.md"
COSTS="$BASE/COSTS.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$SETUP" ]; then
  echo "FAIL: $SETUP does not exist. Student must produce it."
  exit 1
fi
if [ ! -f "$COSTS" ]; then
  echo "FAIL: $COSTS does not exist. Student must produce it."
  exit 1
fi

# Each of the 7 ordered steps must appear as a heading mentioning its topic.
step_checks=(
  "MFA"           # Paso 1
  "access key"    # Paso 2
  "Billing"       # Paso 3
  "Budget|presupuesto"  # Paso 4
  "Admin|admin"   # Paso 5
  "root"          # Paso 6 — cerrar sesion de root
  "CloudTrail"    # Paso 7
)
for i in 1 2 3 4 5 6 7; do
  pattern="${step_checks[$((i-1))]}"
  if grep -qiE "^#+ *Paso +${i}\\b.*(${pattern})" "$SETUP"; then
    echo "  OK   ACCOUNT-SETUP.md has Paso $i (matches /${pattern}/)"
  else
    echo "  FAIL ACCOUNT-SETUP.md missing Paso $i or does not mention ${pattern}"
    fail=$((fail+1))
  fi
done

# At least 7 bash code fences (one per step minimum).
fences=$(grep -cE '^```bash' "$SETUP" || true)
if [ "$fences" -ge 7 ]; then
  echo "  OK   ACCOUNT-SETUP.md has $fences bash code blocks (>=7)"
else
  echo "  FAIL ACCOUNT-SETUP.md has only $fences bash code blocks (expected >=7)"
  fail=$((fail+1))
fi

# Must mention sts get-caller-identity at least once as a verification idiom.
if grep -qi 'get-caller-identity' "$SETUP"; then
  echo "  OK   ACCOUNT-SETUP.md mentions sts get-caller-identity"
else
  echo "  FAIL ACCOUNT-SETUP.md does not mention sts get-caller-identity"
  fail=$((fail+1))
fi

# Must have the "Cargos silenciosos" section with at least 5 bullet items.
if grep -qiE '^#+ *Cargos silenciosos' "$SETUP"; then
  echo "  OK   ACCOUNT-SETUP.md has 'Cargos silenciosos' section"
  bullets=$(awk '/^#+ *Cargos silenciosos/{flag=1; next} /^#/{flag=0} flag && /^[[:space:]]*[-*]/{c++} END{print c+0}' "$SETUP")
  if [ "$bullets" -ge 5 ]; then
    echo "  OK   'Cargos silenciosos' lists $bullets items (>=5)"
  else
    echo "  FAIL 'Cargos silenciosos' lists only $bullets items (expected >=5)"
    fail=$((fail+1))
  fi
else
  echo "  FAIL ACCOUNT-SETUP.md missing 'Cargos silenciosos' section"
  fail=$((fail+1))
fi

# Must use the placeholder account id 123456789012 (no real id).
if grep -q '123456789012' "$SETUP"; then
  echo "  OK   uses placeholder AccountId 123456789012"
else
  echo "  FAIL does not use placeholder AccountId 123456789012 (required to avoid leaking real IDs)"
  fail=$((fail+1))
fi

# ---- COSTS.md checks ----

# Must have Workload and Estimacion sections.
if grep -qiE '^#+ *Workload' "$COSTS"; then
  echo "  OK   COSTS.md has Workload section"
else
  echo "  FAIL COSTS.md missing Workload section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *Estimaci[oó]n' "$COSTS"; then
  echo "  OK   COSTS.md has Estimacion section"
else
  echo "  FAIL COSTS.md missing Estimacion section"
  fail=$((fail+1))
fi

# Table must have at least 4 pipe rows (header+sep+data).
rows=$(grep -cE '^\|' "$COSTS" || true)
if [ "$rows" -ge 4 ]; then
  echo "  OK   COSTS.md has $rows pipe-lines (>=4)"
else
  echo "  FAIL COSTS.md has only $rows pipe-lines (expected >=4)"
  fail=$((fail+1))
fi

# Must mention USD and some number.
if grep -qE 'USD' "$COSTS"; then
  echo "  OK   COSTS.md mentions USD"
else
  echo "  FAIL COSTS.md does not mention USD"
  fail=$((fail+1))
fi

# Must mention Free Tier.
if grep -qiE 'free[- ]?tier' "$COSTS"; then
  echo "  OK   COSTS.md mentions Free Tier"
else
  echo "  FAIL COSTS.md does not mention Free Tier"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/TEMPLATE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ACCOUNT-SETUP.md y COSTS.md con solution/TEMPLATE.md."
exit 0
