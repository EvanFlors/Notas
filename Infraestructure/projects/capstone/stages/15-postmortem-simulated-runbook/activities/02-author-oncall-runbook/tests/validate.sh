#!/usr/bin/env bash
# Validator for cap-15-02-author-oncall-runbook.
#
# Note: using `set -eu` but deliberately NOT `set -o pipefail` because several
# checks use `grep | wc -l` style pipes, which can emit SIGPIPE (exit 141) and
# would be flagged as spurious failures under pipefail.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/cap-15-02}}"
FILE="$BASE/runbook.md"

issues=0
report=""

ok()  { report+="  OK   — $1\n"; }
bad() { report+="  FAIL — $1\n"; issues=$((issues+1)); }

echo "== Validating cap-15-02 under $BASE =="

if [ ! -d "$BASE" ]; then
  bad "base dir missing: $BASE"
  printf "%b" "$report"
  echo "RESULT: $issues issue(s)"
  exit 1
fi
ok "base dir present"

if [ ! -f "$FILE" ]; then
  bad "$FILE missing (copy runbook/TEMPLATE.md there and edit it)"
  printf "%b" "$report"
  echo "RESULT: $issues issue(s)"
  exit 1
fi
ok "runbook.md present"

# --- Required sections ---
sections=(
  "## 1. Symptoms"
  "## 2. Diagnostics"
  "## 3. Mitigations"
  "## 4. Escalation"
  "## 5. Recovery"
  "## 6. Verification"
)
for s in "${sections[@]}"; do
  if grep -Fq "$s" "$FILE"; then
    ok "section present: '$s'"
  else
    bad "section missing: '$s'"
  fi
done

# --- Diagnostics: >= 2 executable code blocks under section 2 ---
diag_block=$(awk '/^## 2\. Diagnostics/{flag=1;next} /^## 3\./{flag=0} flag' "$FILE" || true)
diag_fences=$(printf "%s\n" "$diag_block" | grep -cE '^```' || true)
# each code block = 2 fences
diag_code=$((diag_fences / 2))
if [ "$diag_code" -ge 2 ]; then
  ok "diagnostics has $diag_code executable code block(s) (>=2)"
else
  bad "diagnostics has only $diag_code code block(s) (need >=2)"
fi

# --- Mitigations: >= 2 subheadings ("### Mitigación" / "### Mitigation") ---
mit_block=$(awk '/^## 3\. Mitigations/{flag=1;next} /^## 4\./{flag=0} flag' "$FILE" || true)
mit_subs=$(printf "%s\n" "$mit_block" | grep -cE '^### (Mitigaci|Mitigation)' || true)
if [ "$mit_subs" -ge 2 ]; then
  ok "mitigations: $mit_subs ordered steps (>=2)"
else
  bad "mitigations: $mit_subs (need >=2 '### Mitigación N' subheadings)"
fi

# Mitigations: at least one anti-pattern "No hagas" / "Do not"
if printf "%s\n" "$mit_block" | grep -Eiq 'No hagas|Do not|Don[’'\'']t'; then
  ok "mitigations include at least one anti-pattern note"
else
  bad "mitigations lack 'No hagas:' / 'Do not' guidance"
fi

# --- Symptoms: must mention an alert name and a log/metric pattern ---
sym_block=$(awk '/^## 1\. Symptoms/{flag=1;next} /^## 2\./{flag=0} flag' "$FILE" || true)
if printf "%s\n" "$sym_block" | grep -Eiq 'alert'; then
  ok "symptoms mention alert(s)"
else
  bad "symptoms do not mention any alert"
fi
if printf "%s\n" "$sym_block" | grep -Eiq 'logql|promql|grafana|loki|logs|dashboard'; then
  ok "symptoms reference observability signals (logs/metrics/dashboards)"
else
  bad "symptoms lack observability signal references"
fi

# --- Diagnostics: >= 2 'descartes' (false-lead disambiguation) ---
descartes=$(printf "%s\n" "$diag_block" | grep -cEi 'descarta|discard|desambigua|if you see|si ves' || true)
if [ "$descartes" -ge 2 ]; then
  ok "diagnostics have $descartes false-lead disambiguations (>=2)"
else
  bad "diagnostics have only $descartes disambiguations (need >=2 — 'si ves X es otro runbook')"
fi

# --- Verification: >= 4 checkbox items ---
ver_block=$(awk '/^## 6\. Verification/{flag=1;next} /^## 7\./{flag=0; exit} flag' "$FILE" || true)
checks=$(printf "%s\n" "$ver_block" | grep -cE '^- \[ \]' || true)
if [ "$checks" -ge 4 ]; then
  ok "verification has $checks checkboxes (>=4)"
else
  bad "verification has only $checks checkbox(es) (need >=4)"
fi

# --- Escalation: must have quantitative trigger (>=, >, <, min, %) ---
esc_block=$(awk '/^## 4\. Escalation/{flag=1;next} /^## 5\./{flag=0} flag' "$FILE" || true)
if printf "%s\n" "$esc_block" | grep -Eq '[0-9]+[[:space:]]*(min|%|s|ms)'; then
  ok "escalation uses quantitative trigger"
else
  bad "escalation lacks a quantitative trigger (e.g. '>10 min', '>90%')"
fi

# --- Blameless language check (runbooks too) ---
flags_words=("fault of" "blame" "stupid" "careless" "idiot" "culpa de")
flagged=0
for w in "${flags_words[@]}"; do
  if grep -iq "$w" "$FILE"; then
    bad "blame-flag word detected: '$w'"
    flagged=1
  fi
done
[ "$flagged" -eq 0 ] && ok "no blame-flag words detected"

echo
printf "%b" "$report"
echo
echo "RESULT: $issues issue(s)"
if [ "$issues" -eq 0 ]; then
  exit 0
else
  exit 1
fi
