#!/usr/bin/env bash
# Validate k8s-13-02: ADR structure for Karpenter vs CAS decision.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# use pipelines with `grep -q` or `grep -c`. pipefail would surface spurious
# SIGPIPE/early-exit failures when grep terminates before upstream.

BASE_DIR="${BASE_DIR:-/tmp/k8s-13-02}"
ADR="$BASE_DIR/docs/adr/0001-autoscaler-choice.md"

passed=0
failed=0
report=""

check_file_exists() {
  local name="ADR file exists at docs/adr/0001-autoscaler-choice.md"
  if [ -f "$ADR" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — expected $ADR\n"; failed=$((failed+1))
  fi
}

check_section() {
  local heading="$1"
  local label="$2"
  local name="Section present: $label"
  if [ -f "$ADR" ] && grep -q "^${heading}" "$ADR"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — '^${heading}' not found\n"; failed=$((failed+1))
  fi
}

check_status_accepted() {
  local name="Status is Accepted with a subject"
  if [ ! -f "$ADR" ]; then
    report+="$name: FAIL (no ADR)\n"; failed=$((failed+1)); return
  fi
  # Expect a line like: "Accepted: Karpenter v1" (anything non-empty after the colon).
  if awk '/^## Status/{flag=1; next} /^## /{flag=0} flag' "$ADR" \
       | grep -Eq '^Accepted:[[:space:]]+.+'; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — need a line 'Accepted: <decision subject>' under ## Status\n"
    failed=$((failed+1))
  fi
}

check_table_rows() {
  local name="Comparison table has >=6 dimension rows"
  if [ ! -f "$ADR" ]; then
    report+="$name: FAIL (no ADR)\n"; failed=$((failed+1)); return
  fi
  # Count table body rows: pipe-prefixed lines, excluding the separator (|---|---|...)
  # which is composed only of |, -, :, and whitespace end-to-end. Then subtract 1 for
  # the header row.
  local total_rows sep_rows rows
  total_rows="$(grep -Ec '^\|' "$ADR")"
  sep_rows="$(grep -Ec '^[|[:space:]:-]+$' "$ADR")"
  total_rows="${total_rows:-0}"
  sep_rows="${sep_rows:-0}"
  rows=$(( total_rows - sep_rows ))
  # Subtract 1 for the header row (if any table at all exists).
  if [ "$rows" -gt 0 ]; then
    rows=$((rows - 1))
  fi
  if [ "$rows" -ge 6 ] 2>/dev/null; then
    report+="$name: OK (rows=$rows)\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — found $rows dimension row(s); need >=6\n"
    failed=$((failed+1))
  fi
}

check_links() {
  local name="References section has >=3 URLs"
  if [ ! -f "$ADR" ]; then
    report+="$name: FAIL (no ADR)\n"; failed=$((failed+1)); return
  fi
  local links
  links="$(grep -Eoc 'https?://[^[:space:])]+' "$ADR" | head -1)"
  links="${links:-0}"
  if [ "$links" -ge 3 ] 2>/dev/null; then
    report+="$name: OK (links=$links)\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — found $links link(s); need >=3\n"
    failed=$((failed+1))
  fi
}

check_rollback_substance() {
  local name="Rollback Plan has >=100 chars of text"
  if [ ! -f "$ADR" ]; then
    report+="$name: FAIL (no ADR)\n"; failed=$((failed+1)); return
  fi
  local body
  body="$(awk '/^## Rollback Plan/{flag=1; next} /^## /{flag=0} flag' "$ADR" \
            | tr -d '[:space:]')"
  local len=${#body}
  if [ "$len" -ge 100 ]; then
    report+="$name: OK (chars=$len)\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — Rollback Plan has only $len non-whitespace chars; need >=100\n"
    failed=$((failed+1))
  fi
}

echo "== Validating k8s-13-02 ADR under $BASE_DIR =="

check_file_exists
check_section "# ADR"              "Title (# ADR ...)"
check_section "## Status"          "## Status"
check_section "## Context"         "## Context"
check_section "## Decision"        "## Decision"
check_section "## Consequences"    "## Consequences"
check_section "## Alternatives"    "## Alternatives"
check_section "## Rollback Plan"   "## Rollback Plan"
check_section "## References"      "## References"
check_status_accepted
check_table_rows
check_links
check_rollback_substance

echo
printf "%b" "$report"
echo

total=$((passed + failed))
if [ "$failed" -eq 0 ]; then
  echo "RESULT: OK — $passed/$total checks passed."
  exit 0
else
  echo "RESULT: FAIL — $passed/$total checks passed, $failed failing."
  exit 1
fi
