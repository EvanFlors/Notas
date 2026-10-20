#!/usr/bin/env bash
# Structural validation for jk-01-02-jenkins-cost-estimate.
# Checks that COST-ESTIMATE.md exists and contains: an estimate heading,
# the 5 required sections, at least 2 Markdown tables (keep + migrate),
# currency mention, hours mention, at least 3 keep categories, at least
# 3 migrate categories, an explicit break-even number, a sensitivity
# mention, and a recommendation.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade numerical correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/jk-01-cost}"
DOC="$BASE/COST-ESTIMATE.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must have a top-level heading mentioning cost / estimate / estimación.
if grep -qiE '^#+ .*(cost|estimate|estimaci[oó]n)' "$DOC"; then
  echo "  OK   COST-ESTIMATE.md has a cost/estimate heading"
else
  echo "  FAIL COST-ESTIMATE.md missing a cost/estimate heading"
  fail=$((fail+1))
fi

# Required sections.
for section in "Supuestos|Assumptions" "Mantener|Keep|Stay" \
               "Migrar|Migrate|Migration" "Break[- ]?even|Payback" \
               "Recomendaci[oó]n|Recommendation"; do
  label="${section%%|*}"
  if grep -qiE "^#+ *(${section})\\b" "$DOC"; then
    echo "  OK   has '${label}' section"
  else
    echo "  FAIL missing '${label}' section"
    fail=$((fail+1))
  fi
done

# Must have at least 2 Markdown pipe-tables (separators '|---').
sep_count=$(grep -cE '^\|[[:space:]]*-+' "$DOC" || true)
if [ "$sep_count" -ge 2 ]; then
  echo "  OK   has at least 2 Markdown tables (${sep_count} separator rows)"
else
  echo "  FAIL has only ${sep_count} Markdown-table separator rows (expected >=2)"
  fail=$((fail+1))
fi

# Currency mention.
if grep -qiE 'USD|EUR|€|\$' "$DOC"; then
  echo "  OK   mentions currency (USD/EUR/€/\$)"
else
  echo "  FAIL does not mention currency (USD/EUR/€/\$)"
  fail=$((fail+1))
fi

# Hours mention.
if grep -qiE 'hora|hour|\bh/\|\bhrs\b|\bh +anual' "$DOC"; then
  echo "  OK   mentions hours as effort unit"
else
  echo "  FAIL does not mention hours as effort unit"
  fail=$((fail+1))
fi

# At least 3 "keep" categories.
keep=0
for cat in "personas" "people" "FTE" "plugin" "CVE" "infra" "agents" \
           "controller" "incident" "licencia" "license" "CloudBees"; do
  if grep -qi "$cat" "$DOC"; then
    keep=$((keep+1))
  fi
done
if [ "$keep" -ge 3 ]; then
  echo "  OK   mentions at least 3 keep-side categories (${keep} tokens found)"
else
  echo "  FAIL mentions only ${keep} keep-side categories (expected >=3)"
  fail=$((fail+1))
fi

# At least 3 "migrate" categories.
mig=0
for cat in "inventario" "inventory" "clasificaci" "classificat" \
           "re-escritura" "rewrite" "port" "dual-run" "dual run" \
           "OIDC" "aprendizaje" "learning" "archivado" "archive" "backfill"; do
  if grep -qi "$cat" "$DOC"; then
    mig=$((mig+1))
  fi
done
if [ "$mig" -ge 3 ]; then
  echo "  OK   mentions at least 3 migrate-side categories (${mig} tokens found)"
else
  echo "  FAIL mentions only ${mig} migrate-side categories (expected >=3)"
  fail=$((fail+1))
fi

# Explicit break-even number (digits followed by months/years or 'mes/año').
if grep -qiE '[0-9]+[[:space:]]*(month|mes|a[nñ]o|year)' "$DOC"; then
  echo "  OK   has an explicit break-even number"
else
  echo "  FAIL does not have an explicit break-even number (expected 'N meses' or 'N months' or 'N años')"
  fail=$((fail+1))
fi

# Sensitivity analysis mention.
if grep -qiE 'sensibilidad|sensitivity|\+\/-|\+/-|rango|range|escenario|scenario|worst|peor' "$DOC"; then
  echo "  OK   has a sensitivity / range / scenario mention"
else
  echo "  FAIL does not mention sensitivity / range / scenario"
  fail=$((fail+1))
fi

# Recommendation presence (non-empty section).
rec_lines=$(awk '/^##[[:space:]]+(Recomendaci[oó]n|Recommendation)/{flag=1; next} /^##[[:space:]]/{flag=0} flag' "$DOC" \
            | grep -cE '[A-Za-z]' || true)
if [ "$rec_lines" -ge 1 ]; then
  echo "  OK   Recommendation section has content (${rec_lines} non-empty lines)"
else
  echo "  FAIL Recommendation section is empty"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Numerical correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara COST-ESTIMATE.md con solution/REFERENCE.md para autoevaluarte."
exit 0
