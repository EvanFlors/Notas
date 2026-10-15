#!/usr/bin/env bash
# Validator for tf-13-02-opentofu-eval.
# NOTE: we deliberately do NOT enable `set -o pipefail` because downstream
# `grep -q` can close stdin early (SIGPIPE), which pipefail would misreport.

BASE="${1:-${BASE_DIR:-/tmp/tf-tofu-eval}}"
P="$BASE/project"

pass=0
fail=0
skip=0
report=""
ok()   { report+="  OK   -- $1\n"; pass=$((pass+1)); }
bad()  { report+="  FAIL -- $1\n"; fail=$((fail+1)); }
warn() { report+="  SKIP -- $1\n"; skip=$((skip+1)); }

echo "== Validating tf-13-02 OpenTofu evaluation under $P =="

if [ ! -d "$P" ]; then
  bad "project missing at $P (run starter/bootstrap.sh first)"
  echo; printf "%b" "$report"; echo
  echo "RESULT: $pass OK / $fail FAIL / $skip SKIP  ->  FAIL"
  exit 1
fi

EVID="$P/evidence"
ADR="$P/adr/0001-terraform-vs-opentofu.md"

# ---- tofu installed? ----
HAVE_TOFU=0
if command -v tofu >/dev/null 2>&1; then
  HAVE_TOFU=1
  ok "tofu present: $(tofu version | head -1)"
else
  warn "tofu NOT installed; evidence checks requiring it will be SKIPPED. Install:"
  warn "  brew install opentofu   # or https://opentofu.org/docs/intro/install/"
fi

# ---- evidence/versions.txt ----
if [ ! -s "$EVID/versions.txt" ]; then
  bad "evidence/versions.txt missing or empty"
else
  ok "evidence/versions.txt exists"
  if grep -qi 'Terraform' "$EVID/versions.txt"; then
    ok "versions.txt mentions Terraform"
  else
    bad "versions.txt does not mention Terraform"
  fi
  if [ "$HAVE_TOFU" = "1" ]; then
    if grep -qi 'OpenTofu' "$EVID/versions.txt"; then
      ok "versions.txt mentions OpenTofu"
    else
      bad "versions.txt does not mention OpenTofu (expected with tofu installed)"
    fi
    # Lockfile cross-tool is a KNOWN divergence (registry URL): rc=0 OR rc!=0
    # with a 'note:' line are both acceptable. The student must have RECORDED
    # the result (either outcome) — not left it unchecked.
    if grep -qE 'tofu init -lockfile=readonly rc=[0-9]+' "$EVID/versions.txt"; then
      ok "lockfile cross-tool: tofu init -lockfile=readonly result recorded"
      if grep -q 'tofu init -lockfile=readonly rc=0' "$EVID/versions.txt"; then
        ok "lockfile cross-tool: tofu accepted terraform's lockfile (rc=0)"
      else
        warn "lockfile cross-tool: tofu rejected terraform's lockfile (expected due to registry URL divergence); documented"
      fi
    else
      bad "versions.txt must contain a 'tofu init -lockfile=readonly rc=N' line"
    fi
  else
    warn "lockfile cross-tool check skipped (no tofu)"
  fi
fi

# ---- evidence/state-cross-read.txt ----
if [ "$HAVE_TOFU" = "1" ]; then
  if [ ! -s "$EVID/state-cross-read.txt" ]; then
    bad "evidence/state-cross-read.txt missing or empty"
  else
    ok "evidence/state-cross-read.txt exists"
    if grep -q 'No changes' "$EVID/state-cross-read.txt"; then
      ok "state cross-read reports 'No changes'"
    else
      bad "state-cross-read.txt must contain 'No changes'"
    fi
    if grep -qE '^exit=0' "$EVID/state-cross-read.txt"; then
      ok "state cross-read exit=0"
    else
      bad "state-cross-read.txt must end with 'exit=0'"
    fi
  fi
else
  warn "state cross-read check skipped (no tofu)"
fi

# ---- evidence/plan-diff.txt ----
if [ "$HAVE_TOFU" = "1" ]; then
  if [ ! -e "$EVID/plan-diff.txt" ]; then
    bad "evidence/plan-diff.txt missing"
  else
    if [ ! -s "$EVID/plan-diff.txt" ]; then
      ok "plan-diff.txt is empty (terraform and tofu plans match)"
    else
      bad "plan-diff.txt is non-empty — plans diverge. Review the diff."
    fi
  fi
else
  warn "plan-diff check skipped (no tofu)"
fi

# ---- ADR ----
if [ ! -s "$ADR" ]; then
  bad "adr/0001-terraform-vs-opentofu.md missing or empty"
else
  ok "ADR exists"
  missing_sec=""
  for sec in '## Status' '## Context' '## Decision' '## Consequences' '## Options considered' '## Migration plan'; do
    if ! grep -q "^$sec" "$ADR"; then
      missing_sec+=" '$sec'"
    fi
  done
  # Accept "## Why not migrate" as an alternative to "## Migration plan"
  if echo "$missing_sec" | grep -q "'## Migration plan'"; then
    if grep -q '^## Why not migrate' "$ADR"; then
      missing_sec="$(echo "$missing_sec" | sed "s/'## Migration plan'//")"
    fi
  fi
  if [ -z "$(echo "$missing_sec" | tr -d ' ')" ]; then
    ok "ADR has required sections"
  else
    bad "ADR missing sections:$missing_sec"
  fi
  missing_m=""
  grep -q 'BUSL'                "$ADR" || missing_m+=" BUSL"
  grep -q 'Apache 2.0'          "$ADR" || missing_m+=" 'Apache 2.0'"
  grep -q 'Linux Foundation'    "$ADR" || missing_m+=" 'Linux Foundation'"
  grep -qi 'state encryption'   "$ADR" || missing_m+=" 'state encryption'"
  if [ -z "$missing_m" ]; then
    ok "ADR mentions required concepts (BUSL, Apache 2.0, Linux Foundation, state encryption)"
  else
    bad "ADR missing mentions:$missing_m"
  fi
  # Simple heuristic: options table or list must have >= 2 options & >= 4 criteria.
  # We approximate by counting lines mentioning Terraform and OpenTofu + 4 criterion keywords.
  crit_hits=0
  for kw in 'License|Licencia' 'Features|Caracter' 'Support|Soporte' 'Migration|Migraci'; do
    if grep -qiE "$kw" "$ADR"; then
      crit_hits=$((crit_hits+1))
    fi
  done
  if [ "$crit_hits" -ge 4 ]; then
    ok "ADR covers >=4 criteria (license, features, support, migration)"
  else
    bad "ADR must weigh at least 4 criteria (License, Features, Support, Migration cost). Found $crit_hits/4."
  fi
fi

echo
printf "%b" "$report"
echo
if [ "$fail" -eq 0 ]; then
  if [ "$skip" -gt 0 ]; then
    echo "RESULT: $pass OK / $skip SKIP (install tofu for full PASS)"
    exit 0
  fi
  echo "RESULT: ALL CHECKS PASS ($pass/$pass)"
  exit 0
else
  echo "RESULT: $pass OK / $fail FAIL / $skip SKIP  ->  FAIL"
  exit 1
fi
