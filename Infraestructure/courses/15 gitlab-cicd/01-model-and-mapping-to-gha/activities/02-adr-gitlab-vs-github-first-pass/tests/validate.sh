#!/usr/bin/env bash
# Structural validation for gl-01-02-adr-gitlab-vs-github-first-pass.
# Checks that ADR-GITLAB-VS-GITHUB.md exists and has the ADR sections,
# compares equivalent plans (not Free vs Free), covers minimum decision axes,
# and lists at least two discarded alternatives.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `grep -c` or `grep -q` which can emit SIGPIPE (exit 141) when matches
# happen early. pipefail would spuriously mark those as failures.
#
# Does NOT grade argumentation. Compare manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gl-01-02}"
DOC="$BASE/ADR-GITLAB-VS-GITHUB.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Must look like an ADR (title mentioning ADR).
if grep -qiE '^#+ *ADR' "$DOC"; then
  echo "  OK   ADR-GITLAB-VS-GITHUB.md has an 'ADR' heading"
else
  echo "  FAIL ADR-GITLAB-VS-GITHUB.md missing an 'ADR' heading"
  fail=$((fail+1))
fi

# Required ADR sections.
for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
               "Consecuencias|Consequences" "Alternativas|Alternatives"; do
  label="${section%%|*}"
  if grep -qiE "^#+ *(${section})\\b" "$DOC"; then
    echo "  OK   ADR has '${label}' section"
  else
    echo "  FAIL ADR missing '${label}' section"
    fail=$((fail+1))
  fi
done

# Must mention both platforms explicitly.
if grep -qiE 'GitHub +Actions|\bGHA\b' "$DOC"; then
  echo "  OK   mentions GitHub Actions / GHA"
else
  echo "  FAIL does not mention GitHub Actions / GHA"
  fail=$((fail+1))
fi
if grep -qi 'GitLab' "$DOC"; then
  echo "  OK   mentions GitLab"
else
  echo "  FAIL does not mention GitLab"
  fail=$((fail+1))
fi

# Must mention a real plan comparison (not Free vs Free).
plan_hits=0
for p in "Ultimate" "GHAS" "Advanced +Security" "Premium" "\\bTeam\\b" "Enterprise"; do
  if grep -qiE "$p" "$DOC"; then
    plan_hits=$((plan_hits+1))
  fi
done
if [ "$plan_hits" -ge 2 ]; then
  echo "  OK   compares at least 2 named plan tiers (${plan_hits} tokens: avoids Free-vs-Free trap)"
else
  echo "  FAIL only ${plan_hits} plan tier(s) named (expected >=2: e.g. Ultimate, GHAS, Team, Premium)"
  fail=$((fail+1))
fi

# Must cover at least 3 of the decision axes.
axis=0
for a in "compliance" "SOC *2" "PCI" "OIDC" "Self-Managed" "self-managed" \
         "Subgroup" "subgroup" "\\bGroup\\b" "Marketplace" "Catalog" \
         "migraci[oó]n" "migration" "SSO" "SCIM" "compliance pipeline" \
         "required workflow" "Review App" "environment"; do
  if grep -qiE "$a" "$DOC"; then
    axis=$((axis+1))
  fi
done
if [ "$axis" -ge 3 ]; then
  echo "  OK   covers at least 3 decision axes (${axis} tokens found)"
else
  echo "  FAIL covers only ${axis} decision axes (expected >=3)"
  fail=$((fail+1))
fi

# Must mention Europe / eu-* region constraint.
if grep -qiE 'europ|eu-west|eu-central|eu-south|eu-north' "$DOC"; then
  echo "  OK   mentions Europe / eu-* region constraint"
else
  echo "  FAIL does not mention Europe / eu-* region"
  fail=$((fail+1))
fi

# Must contain at least one Markdown table.
if grep -qE '^\|.*\|' "$DOC" && grep -qE '^\|[ :-]+\|' "$DOC"; then
  echo "  OK   contains at least one Markdown table"
else
  echo "  FAIL does not contain a Markdown table (expected a comparative table)"
  fail=$((fail+1))
fi

# Must have an explicit decision statement.
if grep -qiE 'elegimos|elegir|decidimos|decidir|decisi[oó]n:|decision:' "$DOC"; then
  echo "  OK   has an explicit decision statement"
else
  echo "  FAIL no explicit decision statement (expected 'elegimos ...' / 'decidimos ...')"
  fail=$((fail+1))
fi

# At least 2 discarded alternatives (sub-headings or numbered items).
alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$DOC" || true)
alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$DOC" || true)
if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
  echo "  OK   has at least 2 discarded alternatives"
else
  echo "  FAIL fewer than 2 discarded alternatives (expected >=2 sub-headings or numbered items)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Argumentation quality is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR-GITLAB-VS-GITHUB.md con solution/REFERENCE.md para autoevaluarte."
exit 0
