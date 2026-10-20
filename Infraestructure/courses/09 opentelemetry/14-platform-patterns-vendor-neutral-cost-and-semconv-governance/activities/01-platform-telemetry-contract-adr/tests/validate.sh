#!/usr/bin/env bash
# Structural validator for the platform telemetry contract ADR.
#
# Usage: bash validate.sh [PATH_TO_ADR]
# Default: /tmp/otel-14-01/ADR-telemetry-contract.md
#
# Checks (structural only; no judgement on content):
#   - All 9 required section headings present.
#   - An explicit **Decisión:** line exists.
#   - Section 5 (Riesgos) has >= 3 bullets.
#   - Section 6.2 enumerates >= 5 forbidden vendor prefixes.
#   - Section 6.3 has at least 4 SLO rows in a markdown table.
#   - Section 6.4 mentions "dual-emit" and "cutover".
#   - Section 7 (Alternativas) has >= 2 bullets.
#   - Section 9 (Plan de migración) has >= 3 numbered steps.
#   - No TODO markers left.
#
# Note: we do NOT enable `set -o pipefail`. Several checks use `grep -q` which
# can SIGPIPE upstream and pipefail would spuriously fail.

ADR="${1:-/tmp/otel-14-01/ADR-telemetry-contract.md}"

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

# ----- Check 1: 9 section headings
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

# ----- Check 2: explicit decision line
if grep -Eq '^\*\*Decisi(ó|o)n:\*\*' "$ADR"; then
  ok "explicit decision line present"
else
  bad "no decision line" "expected '**Decisión:**' at line start"
fi

# ----- Check 3: >= 3 risks in section 5
risks_block=$(awk '/^## 5\./{flag=1; next} /^## /{flag=0} flag' "$ADR")
risks_count=$(printf "%s\n" "$risks_block" | grep -cE '^[[:space:]]*[-*][[:space:]]+')
if [ "$risks_count" -ge 3 ]; then
  ok "at least 3 risks enumerated in section 5 (found $risks_count)"
else
  bad "too few risks in section 5" "found $risks_count bullets, need >= 3"
fi

# ----- Check 4: >= 5 forbidden vendor prefixes in section 6
dec_block=$(awk '/^## 6\./{flag=1; next} /^## /{flag=0} flag' "$ADR")
# Count distinct prefix-looking bullets like `dd.*`, `datadog.*`, etc.
prefix_count=$(printf "%s\n" "$dec_block" | grep -cE '^[[:space:]]*[-*][[:space:]]+`[a-zA-Z]+\.\*`')
if [ "$prefix_count" -ge 5 ]; then
  ok "at least 5 forbidden vendor prefixes listed (found $prefix_count)"
else
  bad "too few forbidden vendor prefixes" "found $prefix_count, need >= 5"
fi

# ----- Check 5: >= 4 SLO rows in a markdown table under section 6
# A table row looks like "| ... | ... |" and we exclude headings/separators.
slo_rows=$(printf "%s\n" "$dec_block" | grep -cE '^\|[^|]+\|[^|]+\|$')
# Subtract 2 for header + separator rows of the SLO table.
if [ "$slo_rows" -ge 6 ]; then
  ok "at least 4 SLO rows present (table rows found: $slo_rows incl. header)"
else
  bad "too few SLO rows" "table rows found $slo_rows; need >= 6 (header + sep + 4 data)"
fi

# ----- Check 6: deprecation process mentions dual-emit and cutover
if grep -q 'dual-emit' "$ADR" && grep -q 'cutover' "$ADR"; then
  ok "deprecation process mentions 'dual-emit' and 'cutover'"
else
  bad "deprecation process incomplete" "section 6.4 must mention 'dual-emit' and 'cutover'"
fi

# ----- Check 7: >= 2 alternatives in section 7
alts_block=$(awk '/^## 7\./{flag=1; next} /^## /{flag=0} flag' "$ADR")
alts_count=$(printf "%s\n" "$alts_block" | grep -cE '^[[:space:]]*[-*][[:space:]]+')
if [ "$alts_count" -ge 2 ]; then
  ok "at least 2 alternatives enumerated in section 7 (found $alts_count)"
else
  bad "too few alternatives" "found $alts_count bullets, need >= 2"
fi

# ----- Check 8: >= 3 migration steps in section 9
mig_block=$(awk '/^## 9\./{flag=1; next} /^## /{flag=0} flag' "$ADR")
mig_count=$(printf "%s\n" "$mig_block" | grep -cE '^[[:space:]]*[0-9]+\.[[:space:]]+')
if [ "$mig_count" -ge 3 ]; then
  ok "at least 3 migration steps in section 9 (found $mig_count)"
else
  bad "too few migration steps" "found $mig_count numbered items, need >= 3"
fi

# ----- Check 9: no TODO markers
if grep -q 'TODO' "$ADR"; then
  bad "TODO markers still present" "$(grep -c TODO "$ADR") lines still contain 'TODO'"
else
  ok "no TODO markers left"
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
