#!/usr/bin/env bash
# Validator for cap-15-03-debug-broken-timeline.
#
# Note: using `set -eu` but deliberately NOT `set -o pipefail` because several
# checks use `grep | wc -l` style pipes, which can emit SIGPIPE (exit 141) and
# would be flagged as spurious failures under pipefail.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/cap-15-03}}"
FILE="$BASE/postmortem.md"

issues=0
report=""

ok()  { report+="  OK   — $1\n"; }
bad() { report+="  FAIL — $1\n"; issues=$((issues+1)); }

echo "== Validating cap-15-03 under $BASE =="

if [ ! -f "$FILE" ]; then
  bad "$FILE missing (copy starter/postmortem.md there and fix it)"
  printf "%b" "$report"
  echo "RESULT: $issues issue(s)"
  exit 1
fi
ok "postmortem.md present"

# --- Timeline: >= 6 rows with HH:MM in column 1 ---
timeline_hits=$(grep -cE '^\|[[:space:]]*[0-2][0-9]:[0-5][0-9]' "$FILE" || true)
if [ "$timeline_hits" -ge 6 ]; then
  ok "timeline has $timeline_hits events with HH:MM (>=6)"
else
  bad "timeline has only $timeline_hits events with HH:MM (need >=6)"
fi

# --- Blameless language ---
flags_words=("fault of" "blame" "stupid" "careless" "idiot" "culpa de")
flagged=0
for w in "${flags_words[@]}"; do
  if grep -iq "$w" "$FILE"; then
    bad "blame-flag word detected: '$w' — rewrite in terms of systems/process"
    flagged=1
  fi
done
[ "$flagged" -eq 0 ] && ok "no blame-flag words detected"

# --- Every AI-NN row must have Owner and Due filled ---
# Expected pipe layout: | AI-NN | desc | type | sev | owner | due |
ai_total=0
ai_bad=0
while IFS= read -r line; do
  ai_total=$((ai_total+1))
  # Split by | and strip spaces
  owner=$(printf "%s" "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$6); print $6}')
  due=$(printf "%s" "$line"   | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$7); print $7}')
  id=$(printf "%s" "$line"    | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2}')
  if [ -z "$owner" ] || [ -z "$due" ]; then
    bad "action item $id missing owner or due (owner='$owner' due='$due')"
    ai_bad=$((ai_bad+1))
  fi
done < <(grep -E '^\|[[:space:]]*AI-[0-9]+' "$FILE" || true)

if [ "$ai_total" -lt 3 ]; then
  bad "action items: $ai_total (need >=3)"
else
  ok "action items: $ai_total rows found"
fi
if [ "$ai_total" -gt 0 ] && [ "$ai_bad" -eq 0 ]; then
  ok "all action items have owner and due filled"
fi

# At least one preventive
if grep -Eiq '\|[[:space:]]*preventive[[:space:]]*\|' "$FILE"; then
  ok "at least one preventive action item present"
else
  bad "no 'preventive' action item found"
fi

# --- Required sections (minimal set — the starter already has them, we just confirm) ---
for s in "## 1. Summary" "## 3. Timeline" "## 6. Root cause" "## 11. Action items"; do
  if grep -Fq "$s" "$FILE"; then
    ok "section present: '$s'"
  else
    bad "section missing: '$s'"
  fi
done

echo
printf "%b" "$report"
echo
echo "RESULT: $issues issue(s)"
if [ "$issues" -eq 0 ]; then
  exit 0
else
  exit 1
fi
