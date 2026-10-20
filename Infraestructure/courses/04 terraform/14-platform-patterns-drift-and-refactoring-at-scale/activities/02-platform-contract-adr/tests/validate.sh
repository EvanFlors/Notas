#!/usr/bin/env bash
# Structural validation of the ADR produced in tf-14-02.
# Checks sections, decision count, metrics with numbers, Q&A entries, density.
#
# Usage:
#   bash validate.sh                      # default /tmp/tf14-act02/adr.md
#   bash validate.sh /path/to/adr.md
#
# NO `set -o pipefail` on purpose: grep -q short-circuits produce SIGPIPE on
# upstream commands and would spuriously fail checks.

ADR="${1:-${ADR:-/tmp/tf14-act02/adr.md}}"
passed=0
failed=0
report=""

add_pass() { report+="  OK   $1\n"; passed=$((passed+1)); }
add_fail() { report+="  FAIL $1\n"; failed=$((failed+1)); }

echo "== Validating ADR at: $ADR =="

if [ ! -f "$ADR" ]; then
  echo "FAIL: ADR not found at $ADR"
  echo "hint: run starter/bootstrap.sh and copy adr-template.md to adr.md"
  exit 1
fi

content="$(cat "$ADR")"

# ---- Required top-level sections, in order ----
required_sections=(
  "## Status"
  "## Context"
  "## Decisions"
  "## Trade-offs"
  "## SLOs and metrics"
  "## Consequences"
  "## Alternatives considered"
)

last_pos=-1
order_ok=1
for sec in "${required_sections[@]}"; do
  if echo "$content" | grep -qxF "$sec"; then
    add_pass "section present: $sec"
    pos=$(grep -nxF "$sec" "$ADR" | head -n1 | cut -d: -f1)
    if [ "$pos" -le "$last_pos" ]; then
      order_ok=0
    fi
    last_pos="$pos"
  else
    add_fail "section missing: $sec"
    order_ok=0
  fi
done

if [ "$order_ok" = "1" ]; then
  add_pass "sections appear in the expected order"
else
  add_fail "sections not in the expected order (or some missing)"
fi

# ---- At least 5 decisions ----
dec_count=$(grep -c '^### Decision [0-9]' "$ADR" || true)
if [ "$dec_count" -ge 5 ]; then
  add_pass "decisions found: $dec_count (>=5)"
else
  add_fail "decisions found: $dec_count (expected >=5)"
fi

# ---- At least 3 numeric metrics in SLO section ----
# crude but effective: count lines in the file that have a bullet AND a digit AND a unit-ish token
metric_lines=$(grep -cE '^[-*].*[0-9].*(h|hora|day|dia|días|dias|%|min|s|ms|GB|MB)' "$ADR" || true)
if [ "$metric_lines" -ge 3 ]; then
  add_pass "numeric metrics bullets: $metric_lines (>=3)"
else
  add_fail "numeric metrics bullets: $metric_lines (expected >=3 lines with number + unit)"
fi

# ---- Trade-offs explicitly mention autonomy and security/control ----
if echo "$content" | grep -qi 'autonom'; then
  add_pass "trade-offs mention autonomía/autonomy"
else
  add_fail "trade-offs do not mention autonomía"
fi
if echo "$content" | grep -qiE 'seguridad|security|control'; then
  add_pass "trade-offs mention seguridad/security/control"
else
  add_fail "trade-offs do not mention seguridad/security/control"
fi

# ---- Defense Q&A section with >=3 Q entries ----
if echo "$content" | grep -qx '## Defense Q&A'; then
  add_pass "section present: ## Defense Q&A"
  qcount=$(grep -cE '^\*\*Q[0-9]+:' "$ADR" || true)
  if [ "$qcount" -ge 3 ]; then
    add_pass "defense questions: $qcount (>=3)"
  else
    add_fail "defense questions: $qcount (expected >=3, format **Q1:**)"
  fi
else
  add_fail "section missing: ## Defense Q&A"
fi

# ---- Density: >=50 non-empty lines (ADRs are prose; this flags obvious stubs) ----
nonempty=$(grep -cvE '^[[:space:]]*$' "$ADR" || true)
if [ "$nonempty" -ge 50 ]; then
  add_pass "non-empty lines: $nonempty (>=50)"
else
  add_fail "non-empty lines: $nonempty (expected >=50 — ADR looks stubby)"
fi

echo
printf "%b" "$report"
echo "---"
echo "passed: $passed   failed: $failed"
if [ "$failed" -gt 0 ]; then exit 1; fi
exit 0
