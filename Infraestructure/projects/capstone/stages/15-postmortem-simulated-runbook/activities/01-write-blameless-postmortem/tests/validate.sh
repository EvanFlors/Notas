#!/usr/bin/env bash
# Validator for cap-15-01-write-blameless-postmortem.
#
# Note: using `set -eu` but deliberately NOT `set -o pipefail` because several
# checks use `grep | wc -l` or `grep | head`, which can emit SIGPIPE (exit 141)
# and would be flagged as spurious failures under pipefail.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/cap-15-01}}"
FILE="$BASE/postmortem.md"

issues=0
report=""

ok()  { report+="  OK   — $1\n"; }
bad() { report+="  FAIL — $1\n"; issues=$((issues+1)); }

echo "== Validating cap-15-01 under $BASE =="

if [ ! -d "$BASE" ]; then
  bad "base dir missing: $BASE"
  printf "%b" "$report"
  echo "RESULT: $issues issue(s)"
  exit 1
fi
ok "base dir present"

if [ ! -f "$FILE" ]; then
  bad "$FILE missing (copy postmortem/TEMPLATE.md there and edit it)"
  printf "%b" "$report"
  echo "RESULT: $issues issue(s)"
  exit 1
fi
ok "postmortem.md present"

# --- Required sections (Google SRE) ---
sections=(
  "## 1. Summary"
  "## 2. Impact"
  "## 3. Timeline"
  "## 4. Detection"
  "## 5. Trigger"
  "## 6. Root cause"
  "## 7. Resolution"
  "## 8. What went well"
  "## 9. What went wrong"
  "## 11. Action items"
  "## 12. Lessons learned"
)
for s in "${sections[@]}"; do
  if grep -Fq "$s" "$FILE"; then
    ok "section present: '$s'"
  else
    bad "section missing: '$s'"
  fi
done

# --- Timeline must have >= 6 HH:MM entries ---
timeline_hits=$(grep -cE '^\|[[:space:]]*[0-2][0-9]:[0-5][0-9]' "$FILE" || true)
if [ "$timeline_hits" -ge 6 ]; then
  ok "timeline has $timeline_hits events with HH:MM (>=6)"
else
  bad "timeline has only $timeline_hits events with HH:MM (need >=6)"
fi

# --- Action items table: must have Owner and Due columns, >=3 data rows ---
if grep -Eiq '\|[[:space:]]*Owner[[:space:]]*\|' "$FILE" \
   && grep -Eiq '\|[[:space:]]*Due[[:space:]]*\|' "$FILE"; then
  ok "action items table has Owner and Due columns"
else
  bad "action items table missing Owner/Due columns"
fi

# Count AI-NN rows
ai_rows=$(grep -cE '^\|[[:space:]]*AI-[0-9]+' "$FILE" || true)
if [ "$ai_rows" -ge 3 ]; then
  ok "action items: $ai_rows (>=3)"
else
  bad "action items: $ai_rows (need >=3 rows like 'AI-01')"
fi

# At least one preventive
if grep -Eiq '\|[[:space:]]*preventive[[:space:]]*\|' "$FILE"; then
  ok "at least one preventive action item present"
else
  bad "no 'preventive' action item found (need at least one)"
fi

# --- Blameless language check ---
flags=("fault of" "blame" "stupid" "careless" "idiot" "culpa de")
flagged=0
for w in "${flags[@]}"; do
  if grep -iq "$w" "$FILE"; then
    bad "blame-flag word detected: '$w' — rewrite in terms of systems/process"
    flagged=1
  fi
done
[ "$flagged" -eq 0 ] && ok "no blame-flag words detected"

# --- Root cause depth: at least 2 'porque'/'Porque' or 2 'because' bullets ---
rc_depth=$(grep -cEi '(porque|because)[[:space:]]+[0-9]' "$FILE" || true)
if [ "$rc_depth" -ge 2 ]; then
  ok "root cause has $rc_depth 'porque/because' levels (>=2)"
else
  bad "root cause depth insufficient ($rc_depth); need >=2 'Porque N:'/'Because N:' bullets"
fi

# --- Quantified impact: at least one % and one number in Impact section ---
impact_block=$(awk '/^## 2\. Impact/{flag=1;next} /^## 3\./{flag=0} flag' "$FILE" || true)
if printf "%s" "$impact_block" | grep -qE '%'; then
  ok "impact section contains a percentage"
else
  bad "impact section lacks a percentage — quantify (e.g. '4.7%% requests failed')"
fi
if printf "%s" "$impact_block" | grep -qE '[0-9]{2,}'; then
  ok "impact section contains numeric magnitudes"
else
  bad "impact section lacks numbers (users, requests, duration)"
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $issues issue(s)"
if [ "$issues" -eq 0 ]; then
  exit 0
else
  exit 1
fi
