#!/usr/bin/env bash
# Structural validator for the final ADR (argo-13-02).
# Does not judge content — only ensures the ADR has required sections and density.
#
# Note: we intentionally do NOT enable `set -o pipefail`. Several checks use
# `cmd | grep -q ...`; grep closes early on match and the upstream command may
# receive SIGPIPE (exit 141). pipefail would mark those as failure spuriously.
set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"
ADR="$HERE/solution/ADR-argocd-vs-flux.md"

pass=0; fail=0; report=""
ok()  { report+="PASS: $1"$'\n'; pass=$((pass+1)); }
bad() { report+="FAIL: $1"$'\n'; fail=$((fail+1)); }

if [ ! -f "$ADR" ]; then
  echo "FAIL: $ADR not found. Write your ADR there."
  exit 1
fi

# 1) Starts with H1 ADR header
if head -n 5 "$ADR" | grep -qE '^# ADR[- ]?[0-9]+'; then
  ok "H1 starts with 'ADR-NNN'"
else
  bad "H1 should match '# ADR-NNN: ...'"
fi

# 2) Required sections present (as H2).
for section in Status Context "Decision Drivers" "Considered Options" "Decision Outcome" Consequences "Exit Plan"; do
  if grep -qE "^## +${section}\b" "$ADR"; then
    ok "section '## ${section}' present"
  else
    bad "section '## ${section}' missing"
  fi
done

# 3) Decision Outcome is non-empty (has at least one non-blank line between it and next ##).
outcome="$(awk '/^## Decision Outcome/{flag=1; next} /^## /{flag=0} flag' "$ADR" | tr -d '[:space:]')"
if [ -n "$outcome" ]; then
  ok "'Decision Outcome' is non-empty"
else
  bad "'Decision Outcome' section is empty"
fi

# 4) Weighted criteria evidence: look for '%', 'peso' or 'weight'.
if grep -qiE '(%|\bpeso\b|\bweight\b)' "$ADR"; then
  ok "criteria appear to be weighted (found '%'/'peso'/'weight')"
else
  bad "no weight indicators found ('%', 'peso', 'weight')"
fi

# 5) Length >= 250 words.
words="$(wc -w < "$ADR" | tr -d ' ')"
if [ "${words:-0}" -ge 250 ]; then
  ok "ADR length is $words words (>= 250)"
else
  bad "ADR too short: $words words (expected >= 250)"
fi

# 6) At least mentions both Argo CD and Flux.
if grep -qiE 'argo ?cd' "$ADR" && grep -qi 'flux' "$ADR"; then
  ok "mentions both 'Argo CD' and 'Flux'"
else
  bad "must mention both 'Argo CD' and 'Flux' explicitly"
fi

echo
printf "%s" "$report"
echo
echo "RESULT: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
