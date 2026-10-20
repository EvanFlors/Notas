#!/usr/bin/env bash
# Validate structure and presence of required content in the ADR.
# This is a mixed-validation activity: semantic correctness is subjective and
# evaluated by peer/instructor; this script only checks structure + required
# markers. No pipefail (grep -q pipelines).

ADR_PATH="${1:-starter/ADR-001-branching-strategy.md}"

# Resolve relative path from the activity directory.
if [ ! -f "$ADR_PATH" ]; then
  # Try relative to this script's parent
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  alt="$script_dir/../$ADR_PATH"
  if [ -f "$alt" ]; then
    ADR_PATH="$alt"
  fi
fi

fail=0

echo "== Validating ADR at $ADR_PATH =="

if [ ! -f "$ADR_PATH" ]; then
  echo "FAIL: ADR file not found at '$ADR_PATH'"
  exit 1
fi

# Required headings (exact strings)
required_sections=(
  "# ADR-001: Branching Strategy"
  "## Status"
  "## Context"
  "## Decision"
  "## Alternatives Considered"
  "## Consequences"
  "## Risks and Mitigations"
  "## Review Triggers"
)

for h in "${required_sections[@]}"; do
  if grep -Fxq "$h" "$ADR_PATH"; then
    echo "  OK   section present: '$h'"
  else
    echo "  FAIL section missing: '$h'"
    fail=$((fail+1))
  fi
done

# No unresolved TODO markers left (the starter is seeded with them)
todo_count=$(grep -c '^TODO:\|^- TODO\|^[[:space:]]*TODO:' "$ADR_PATH" || true)
if [ "$todo_count" -eq 0 ]; then
  echo "  OK   no 'TODO:' markers left (starter placeholders resolved)"
else
  echo "  FAIL $todo_count 'TODO:' marker(s) still present — resolve them"
  fail=$((fail+1))
fi

# Decision statement: must contain one of the valid workflows after "adopt"
decision_ok=0
for wf in \
    "trunk-based development" \
    "GitHub Flow" \
    "GitLab Flow" \
    "GitFlow" \
    "release branches on trunk"; do
  if grep -Eiq "(adopt|choose|select|decide to use|will use)[^\\n]*${wf}" "$ADR_PATH"; then
    decision_ok=1
    echo "  OK   explicit decision found for: $wf"
    break
  fi
done
if [ "$decision_ok" -ne 1 ]; then
  echo "  FAIL no explicit 'We will adopt/choose <workflow>' statement with a valid workflow"
  echo "       (valid: trunk-based development | GitHub Flow | GitLab Flow | GitFlow | release branches on trunk)"
  fail=$((fail+1))
fi

# Alternatives: at least 2 bulleted alternatives inside the section
# Extract the Alternatives Considered section body
alt_section=$(awk '
  /^## Alternatives Considered/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR_PATH")
alt_bullets=$(printf "%s\n" "$alt_section" | grep -cE '^-[[:space:]]+' || true)
if [ "$alt_bullets" -ge 2 ]; then
  echo "  OK   Alternatives Considered has $alt_bullets bullets (>=2)"
else
  echo "  FAIL Alternatives Considered needs >=2 bullets, found $alt_bullets"
  fail=$((fail+1))
fi

# Consequences: at least 3 bullets
cons_section=$(awk '
  /^## Consequences/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR_PATH")
cons_bullets=$(printf "%s\n" "$cons_section" | grep -cE '^-[[:space:]]+' || true)
if [ "$cons_bullets" -ge 3 ]; then
  echo "  OK   Consequences has $cons_bullets bullets (>=3)"
else
  echo "  FAIL Consequences needs >=3 bullets, found $cons_bullets"
  fail=$((fail+1))
fi

# Risks: at least 2 bullets AND each must mention Mitigation
risks_section=$(awk '
  /^## Risks and Mitigations/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR_PATH")
risk_bullets=$(printf "%s\n" "$risks_section" | grep -cE '^-[[:space:]]+' || true)
mitigation_mentions=$(printf "%s\n" "$risks_section" | grep -ciE 'mitigation' || true)
if [ "$risk_bullets" -ge 2 ] && [ "$mitigation_mentions" -ge 2 ]; then
  echo "  OK   Risks and Mitigations has $risk_bullets risks and $mitigation_mentions mitigation mentions (>=2 each)"
else
  echo "  FAIL Risks and Mitigations needs >=2 risks AND >=2 'Mitigation' mentions (got risks=$risk_bullets mitig=$mitigation_mentions)"
  fail=$((fail+1))
fi

# Review Triggers: at least 1 bullet
rev_section=$(awk '
  /^## Review Triggers/ {flag=1; next}
  /^## / && flag {flag=0}
  flag {print}
' "$ADR_PATH")
rev_bullets=$(printf "%s\n" "$rev_section" | grep -cE '^-[[:space:]]+' || true)
if [ "$rev_bullets" -ge 1 ]; then
  echo "  OK   Review Triggers has $rev_bullets bullet(s) (>=1)"
else
  echo "  FAIL Review Triggers needs >=1 bullet, found $rev_bullets"
  fail=$((fail+1))
fi

# Word count soft check
word_count=$(wc -w < "$ADR_PATH" | tr -d ' ')
if [ "$word_count" -ge 400 ]; then
  echo "  OK   word count: $word_count (>=400)"
else
  echo "  FAIL word count: $word_count (<400) — develop the ADR further"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: ADR estructura y contenido mínimo verificados."
echo "   Nota: la corrección semántica/arquitectónica se evalúa en revisión por pares."
exit 0
