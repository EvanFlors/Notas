#!/usr/bin/env bash
# Structural validator for the env-strategy ADR.
#
# Usage: bash validate.sh [PATH_TO_ADR]
# Default: /tmp/tf-08-02/ADR-env-strategy.md
#
# Checks:
#   - All 9 required sections exist (by heading).
#   - A line starting with "**Decisión:**" exists outside the template boilerplate.
#   - At least 3 risks enumerated (section 5).
#   - At least 2 alternatives enumerated (section 7).
#   - At least 3 migration steps enumerated (section 9).
#   - "TODO" markers are gone (student actually filled the template).
#
# Note: we do NOT enable `set -o pipefail`. Several checks use `grep -q` which
# can SIGPIPE upstream and pipefail would spuriously fail.

ADR="${1:-/tmp/tf-08-02/ADR-env-strategy.md}"

passed=0
failed=0
report=""

ok()  { report+="OK   — $1\n"; passed=$((passed+1)); }
bad() { report+="FAIL — $1 — $2\n"; failed=$((failed+1)); }

if [ ! -f "$ADR" ]; then
  echo "FAIL: ADR not found at $ADR" >&2
  exit 1
fi

echo "== Validating ADR at $ADR =="

# ----- Check 1: all 9 section headings present
required_sections=(
  "^## 1\\. Estado"
  "^## 2\\. Fecha"
  "^## 3\\. Autores"
  "^## 4\\. Contexto"
  "^## 5\\. Riesgos del status quo"
  "^## 6\\. Decisi(ó|o)n"
  "^## 7\\. Alternativas consideradas"
  "^## 8\\. Consecuencias"
  "^## 9\\. Plan de migraci(ó|o)n"
)
missing=""
for pat in "${required_sections[@]}"; do
  if ! grep -Eq "$pat" "$ADR"; then
    missing+=" '$pat'"
  fi
done
if [ -z "$missing" ]; then
  ok "9 required sections present"
else
  bad "sections missing" "$missing"
fi

# ----- Check 2: a decision line exists
if grep -Eq '^\*\*Decisi(ó|o)n:\*\*' "$ADR"; then
  ok "explicit decision line present (**Decisión:**)"
else
  bad "no decision line" "expected a line starting with '**Decisión:**' or '**Decision:**'"
fi

# ----- Check 3: at least 3 risks (bullets under section 5)
# Extract the block between '## 5.' and the next '## '
risks_block=$(awk '/^## 5\./{flag=1; next} /^## /{flag=0} flag' "$ADR")
risks_count=$(printf "%s\n" "$risks_block" | grep -cE '^[[:space:]]*[-*][[:space:]]+')
if [ "$risks_count" -ge 3 ]; then
  ok "at least 3 risks enumerated in section 5 (found $risks_count)"
else
  bad "too few risks in section 5" "found $risks_count bullets, need >= 3"
fi

# ----- Check 4: at least 2 alternatives (bullets under section 7)
alts_block=$(awk '/^## 7\./{flag=1; next} /^## /{flag=0} flag' "$ADR")
alts_count=$(printf "%s\n" "$alts_block" | grep -cE '^[[:space:]]*[-*][[:space:]]+')
if [ "$alts_count" -ge 2 ]; then
  ok "at least 2 alternatives enumerated in section 7 (found $alts_count)"
else
  bad "too few alternatives in section 7" "found $alts_count bullets, need >= 2"
fi

# ----- Check 5: at least 3 migration steps (ordered list under section 9)
mig_block=$(awk '/^## 9\./{flag=1; next} /^## /{flag=0} flag' "$ADR")
mig_count=$(printf "%s\n" "$mig_block" | grep -cE '^[[:space:]]*[0-9]+\.[[:space:]]+')
if [ "$mig_count" -ge 3 ]; then
  ok "at least 3 migration steps enumerated in section 9 (found $mig_count)"
else
  bad "too few migration steps in section 9" "found $mig_count numbered items, need >= 3"
fi

# ----- Check 6: no TODO markers left
if grep -q 'TODO' "$ADR"; then
  bad "TODO markers still present" "$(grep -c TODO "$ADR") lines still contain 'TODO'"
else
  ok "no TODO markers left — template fully filled"
fi

echo
printf "%b" "$report"
echo
total=$((passed+failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
