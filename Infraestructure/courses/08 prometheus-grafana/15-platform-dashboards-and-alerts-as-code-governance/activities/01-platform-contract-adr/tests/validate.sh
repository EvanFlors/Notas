#!/usr/bin/env bash
# Validate structure + keywords of /tmp/obs15-01/ADR-OBS-001.md.
# Only checks structure and that key topics are mentioned, not content quality.
#
# Note: deliberately NOT using `set -o pipefail` because `grep -q` on piped
# input can produce SIGPIPE and spuriously fail checks.
set -eu

TARGET="${TARGET:-/tmp/obs15-01/ADR-OBS-001.md}"
passed=0
failed=0
report=""

check() {
  local name="$1" ok="$2" why="$3"
  if [ "$ok" -eq 1 ]; then
    report+="OK   — ${name}\n"; passed=$((passed + 1))
  else
    report+="FAIL — ${name}: ${why}\n"; failed=$((failed + 1))
  fi
}

if [ ! -f "$TARGET" ]; then
  echo "FAIL: no existe $TARGET."
  echo "Copia starter/ADR-OBS-001.md a /tmp/obs15-01/ y edítalo."
  exit 1
fi

# 1-6: required top-level sections, in order
for header in \
  "## Status" \
  "## Context" \
  "## Decision" \
  "## Consequences" \
  "## Alternatives considered" \
  "## Review cadence"
do
  has=0
  if grep -Fxq "$header" "$TARGET"; then
    has=1
  fi
  check "section present: '${header}'" "$has" "falta el header de nivel 2 exacto"
done

# 7: at least 4 required labels mentioned
labels_hit=0
for label in team service env tier region; do
  if grep -qiw "$label" "$TARGET"; then
    labels_hit=$((labels_hit + 1))
  fi
done
if [ "$labels_hit" -ge 4 ]; then
  check "mentions >= 4 governance labels" 1 ""
else
  check "mentions >= 4 governance labels" 0 \
        "sólo $labels_hit (team/service/env/tier/region)"
fi

# 8: three tiers named
tiers_hit=0
for tier in gold silver bronze; do
  if grep -qiw "$tier" "$TARGET"; then
    tiers_hit=$((tiers_hit + 1))
  fi
done
if [ "$tiers_hit" -ge 3 ]; then
  check "mentions 3 tiers (gold/silver/bronze)" 1 ""
else
  check "mentions 3 tiers (gold/silver/bronze)" 0 "sólo $tiers_hit tiers"
fi

# 9: dashboards-as-code tool
has_dac=0
if grep -qiE "grafonnet|grizzly|terraform|jsonnet" "$TARGET"; then
  has_dac=1
fi
check "mentions dashboards-as-code tool" "$has_dac" \
      "menciona grafonnet / grizzly / terraform / jsonnet"

# 10: promtool
has_promtool=0
if grep -qi "promtool" "$TARGET"; then
  has_promtool=1
fi
check "mentions promtool for alert tests" "$has_promtool" "menciona promtool"

# 11: runbook as requirement
has_runbook=0
if grep -qi "runbook" "$TARGET"; then
  has_runbook=1
fi
check "mentions runbook" "$has_runbook" "runbook debe aparecer como requisito de alertas"

# 12: budget / dollars
has_budget=0
if grep -qE '\$[0-9]' "$TARGET"; then
  has_budget=1
fi
check "mentions a budget figure (\$NNN)" "$has_budget" "incluye alguna cifra \$"

# 13: at least two alternatives considered — count non-empty bullet/paragraph lines
alt_section=$(awk '/^## Alternatives considered/,/^## Review cadence/' "$TARGET" \
              | grep -cE '^[[:space:]]*[-*0-9]' || true)
if [ "$alt_section" -ge 2 ]; then
  check "lists >= 2 alternatives" 1 ""
else
  check "lists >= 2 alternatives" 0 \
        "en '## Alternatives considered' sólo detecto $alt_section bullets"
fi

# 14: minimum substantive length
nelines=$(grep -cE '[^[:space:]]' "$TARGET" || true)
if [ "$nelines" -ge 50 ]; then
  check "document has substantive content (>= 50 non-empty lines)" 1 ""
else
  check "document has substantive content (>= 50 non-empty lines)" 0 \
        "sólo $nelines líneas no vacías; amplía el ADR"
fi

echo "== obs-15-01 validation =="
printf "%b" "$report"
echo
echo "RESULT: $passed/14 checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
