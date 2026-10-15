#!/usr/bin/env bash
# Validate gha-05-01-env-vs-repo-secret in MODE=local (default) or MODE=live.
#
# NOTE: deliberately no `set -o pipefail`. Several checks pipe into `grep -q`
# which closes stdin early and can produce SIGPIPE (exit 141) on long producers,
# which would be mis-reported as failures.

BASE="${1:-${BASE_DIR:-/tmp/gha-05-env-vs-repo-secret}}"
MODE="${MODE:-local}"

LOCAL="$BASE/local"
WF="$LOCAL/.github/workflows"
DEPLOY="$WF/deploy.yml"
SMOKE="$WF/smoke.yml"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating ($MODE) under $BASE =="

if [ ! -d "$WF" ]; then
  echo "FAIL: workflows directory not found ($WF). Run starter/bootstrap.sh first." >&2
  exit 1
fi

# ---- 1. Both files exist ----
if [ -f "$DEPLOY" ]; then
  note_ok "deploy.yml exists"
else
  note_fail "deploy.yml missing at $DEPLOY"
fi

if [ -f "$SMOKE" ]; then
  note_ok "smoke.yml exists"
else
  note_fail "smoke.yml missing at $SMOKE"
fi

# ---- 2. Placeholder removed ----
if [ -f "$WF/placeholder.yml" ]; then
  note_fail "placeholder.yml still present; delete it"
else
  note_ok "placeholder.yml removed"
fi

# ---- 3. YAML parses ----
if command -v python3 >/dev/null 2>&1; then
  for f in "$DEPLOY" "$SMOKE"; do
    if [ -f "$f" ]; then
      if python3 -c "import sys,yaml; yaml.safe_load(open(sys.argv[1]))" "$f" >/dev/null 2>&1; then
        note_ok "$(basename "$f") parses as valid YAML"
      else
        note_fail "$(basename "$f") is not valid YAML (or PyYAML missing)"
      fi
    fi
  done
else
  note_fail "python3 not available; cannot validate YAML syntax"
fi

# ---- 4. deploy.yml: top-level permissions contents: read ----
if [ -f "$DEPLOY" ]; then
  # Look for the top-level `permissions:` block (not indented) followed by contents: read.
  if awk '
      BEGIN { in_perm=0; found=0 }
      /^permissions:[[:space:]]*$/ { in_perm=1; next }
      in_perm==1 && /^[[:space:]]+contents:[[:space:]]*read[[:space:]]*$/ { found=1 }
      in_perm==1 && /^[^[:space:]]/ { in_perm=0 }
      END { exit (found==1 ? 0 : 1) }
    ' "$DEPLOY"; then
    note_ok "deploy.yml declares top-level 'permissions: contents: read'"
  else
    note_fail "deploy.yml must have top-level 'permissions:' with 'contents: read'"
  fi

  # ---- 5. deploy.yml: two jobs with environment: staging and production ----
  if grep -Eq '^[[:space:]]+environment:[[:space:]]*staging[[:space:]]*$' "$DEPLOY"; then
    note_ok "deploy.yml has a job with environment: staging"
  else
    note_fail "deploy.yml missing a job with 'environment: staging'"
  fi

  if grep -Eq '^[[:space:]]+environment:[[:space:]]*production[[:space:]]*$' "$DEPLOY"; then
    note_ok "deploy.yml has a job with environment: production"
  else
    note_fail "deploy.yml missing a job with 'environment: production'"
  fi

  # ---- 6. deploy.yml: API_TOKEN as secret, not var ----
  if grep -Eq 'API_TOKEN:[[:space:]]*\$\{\{[[:space:]]*secrets\.API_TOKEN[[:space:]]*\}\}' "$DEPLOY"; then
    note_ok "deploy.yml maps API_TOKEN from secrets.API_TOKEN"
  else
    note_fail "deploy.yml must map API_TOKEN from \${{ secrets.API_TOKEN }}"
  fi

  if grep -Eq 'API_TOKEN:[[:space:]]*\$\{\{[[:space:]]*vars\.' "$DEPLOY"; then
    note_fail "deploy.yml must NOT read API_TOKEN from vars (it's a secret)"
  else
    note_ok "deploy.yml does not read API_TOKEN from vars"
  fi

  # ---- 7. deploy.yml: API_URL, FEATURE_FLAGS, TELEMETRY_URL from vars ----
  for key in API_URL FEATURE_FLAGS TELEMETRY_URL; do
    if grep -Eq "${key}:[[:space:]]*\\\$\\{\\{[[:space:]]*vars\\.${key}[[:space:]]*\\}\\}" "$DEPLOY"; then
      note_ok "deploy.yml maps $key from vars.$key"
    else
      note_fail "deploy.yml must map $key from \${{ vars.$key }}"
    fi

    if grep -Eq "${key}:[[:space:]]*\\\$\\{\\{[[:space:]]*secrets\\." "$DEPLOY"; then
      note_fail "deploy.yml must NOT read $key from secrets (it's config, use vars)"
    fi
  done
fi

# ---- 8. smoke.yml: no environment, no API_TOKEN, references TELEMETRY_URL ----
if [ -f "$SMOKE" ]; then
  if grep -Eq '^[[:space:]]+environment:' "$SMOKE"; then
    note_fail "smoke.yml must NOT declare an environment (uses org/repo-wide var)"
  else
    note_ok "smoke.yml does not declare an environment"
  fi

  if grep -q 'API_TOKEN' "$SMOKE"; then
    note_fail "smoke.yml must NOT reference API_TOKEN"
  else
    note_ok "smoke.yml does not reference API_TOKEN"
  fi

  if grep -Eq 'TELEMETRY_URL:[[:space:]]*\$\{\{[[:space:]]*vars\.TELEMETRY_URL[[:space:]]*\}\}' "$SMOKE"; then
    note_ok "smoke.yml reads TELEMETRY_URL from vars.TELEMETRY_URL"
  else
    note_fail "smoke.yml must read TELEMETRY_URL from \${{ vars.TELEMETRY_URL }}"
  fi

  # Top-level permissions in smoke.yml too (good habit).
  if grep -Eq '^permissions:[[:space:]]*$' "$SMOKE"; then
    note_ok "smoke.yml declares top-level permissions block"
  else
    note_fail "smoke.yml should declare top-level 'permissions:' (contents: read)"
  fi
fi

# ---- 9. MODE=live note (no network checks here; YAML-only activity) ----
if [ "$MODE" = "live" ]; then
  note_ok "MODE=live: structural checks identical; verify in-app values manually (see README 5.5)"
elif [ "$MODE" != "local" ]; then
  note_fail "unknown MODE='$MODE' (use 'local' or 'live')"
fi

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT ($MODE): $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
