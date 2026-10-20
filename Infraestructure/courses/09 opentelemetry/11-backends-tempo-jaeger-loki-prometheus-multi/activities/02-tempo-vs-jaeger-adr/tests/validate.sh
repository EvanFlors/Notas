#!/usr/bin/env bash
# Validate activity 02: ADR has required sections, non-trivial content,
# names a candidate explicitly, lists >= 5 criteria, and has a review trigger.
# No `set -o pipefail` — grep -q with pipes would spuriously flag SIGPIPE.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/otel11-lab02}}"
passed=0
failed=0
report=""

if [ ! -d "$BASE" ]; then
  echo "SKIP: $BASE does not exist. Run starter/setup.sh first."
  exit 0
fi

ADR="$BASE/ADR-0001-tempo-vs-jaeger.md"
if [ ! -f "$ADR" ]; then
  echo "FAIL: $ADR not found"
  exit 1
fi

section_content_len() {
  # Extract text from the heading matching $1 (regex-escaped) up to the next
  # top-level ## heading, strip whitespace, print character count.
  local heading_re="$1"
  awk -v re="$heading_re" '
    $0 ~ re { capture=1; next }
    /^## / && capture { exit }
    capture { print }
  ' "$ADR" | tr -d '[:space:]' | wc -c | tr -d ' '
}

check_section() {
  local name="$1" heading_re="$2"
  if grep -qE "$heading_re" "$ADR"; then
    local n
    n="$(section_content_len "$heading_re")"
    if [ "${n:-0}" -ge 100 ]; then
      report+="Section '$name' present with $n chars: OK\n"
      passed=$((passed+1))
    else
      report+="Section '$name' present but too short ($n < 100 chars): FAIL\n"
      failed=$((failed+1))
    fi
  else
    report+="Section '$name' missing: FAIL\n"
    failed=$((failed+1))
  fi
}

echo "== Validating ADR at $ADR =="

# Status is a Nygard-style metadata line (e.g. `- **Status:** Accepted`), not a section.
status_line="$(grep -E '^\s*[-*]?\s*\*\*Status:\*\*' "$ADR" | head -1 || true)"
if [ -n "$status_line" ] && echo "$status_line" | grep -qiE '(Proposed|Accepted|Rejected|Superseded)' \
   && ! echo "$status_line" | grep -q 'TODO'; then
  report+="Status metadata set ($status_line): OK\n"
  passed=$((passed+1))
else
  report+="Status metadata missing or not Proposed/Accepted/Rejected/Superseded: FAIL\n"
  failed=$((failed+1))
fi

check_section "Context"      '^## Context'
check_section "Decision"     '^## Decision'
check_section "Consequences" '^## Consequences'

# Decision must explicitly mention Tempo or Jaeger (not just in Options).
decision_body="$(awk '/^## Decision/{capture=1; next} /^## /{capture=0} capture' "$ADR")"
if echo "$decision_body" | grep -qE '\b(Tempo|Jaeger)\b'; then
  report+="Decision names Tempo or Jaeger: OK\n"
  passed=$((passed+1))
else
  report+="Decision does NOT explicitly name Tempo or Jaeger: FAIL\n"
  failed=$((failed+1))
fi

# At least 5 criteria bullets anywhere in the ADR.
criteria_count="$(grep -cE '^\s*[-*0-9]+\.?\s+\*?\*?[A-Z]' "$ADR" || true)"
criteria_count="${criteria_count:-0}"
if [ "$criteria_count" -ge 5 ]; then
  report+="At least 5 bullet-criteria found ($criteria_count): OK\n"
  passed=$((passed+1))
else
  report+="Fewer than 5 criteria bullets detected ($criteria_count): FAIL\n"
  failed=$((failed+1))
fi

# Review trigger must be present.
if grep -qiE 'review|reevaluate|re-evaluate' "$ADR"; then
  report+="Review trigger mentioned: OK\n"
  passed=$((passed+1))
else
  report+="No review trigger: FAIL\n"
  failed=$((failed+1))
fi

# Ensure the author did not leave TODOs in Status/Context/Decision.
leftover_todo=0
for sec in '^## Status' '^## Context' '^## Decision'; do
  body="$(awk -v re="$sec" '$0~re{capture=1; next} /^## /{capture=0} capture' "$ADR")"
  if echo "$body" | grep -q 'TODO'; then
    leftover_todo=$((leftover_todo+1))
  fi
done
if [ "$leftover_todo" -eq 0 ]; then
  report+="No TODO markers left in core sections: OK\n"
  passed=$((passed+1))
else
  report+="$leftover_todo core sections still contain TODO: FAIL\n"
  failed=$((failed+1))
fi

echo
printf "%b" "$report"
echo
total=$((passed+failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then exit 1; fi
exit 0
