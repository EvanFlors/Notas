#!/usr/bin/env bash
# Validate gha-02-01-conditional-jobs in MODE=local (default) or MODE=live.
#
# NOTE: deliberately no `set -o pipefail` because many checks use
# `... | grep -q ...` on long-producing commands which can produce SIGPIPE
# (exit 141) and would be mis-reported as failures.

BASE="${1:-${BASE_DIR:-/tmp/gha-02-01}}"
MODE="${MODE:-local}"

WF="$BASE/local/.github/workflows/conditional.yml"
passed=0
failed=0
report=""

note_ok()   { report+="  OK   — $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL — $1\n"; failed=$((failed+1)); }

echo "== Validating gha-02-01 ($MODE) under $BASE =="

if [ ! -f "$WF" ]; then
  echo "FAIL: workflow not found at $WF. Run starter/bootstrap.sh first." >&2
  exit 1
fi

# ---- Check 1: no TODO markers left ----
if grep -q 'TODO' "$WF"; then
  note_fail "quedan marcadores 'TODO' en el workflow"
else
  note_ok "no quedan TODOs en el workflow"
fi

# ---- Check 2: 3 jobs named lint, test, deploy ----
if grep -Eq '^[[:space:]]{2}lint:' "$WF" \
   && grep -Eq '^[[:space:]]{2}test:' "$WF" \
   && grep -Eq '^[[:space:]]{2}deploy:' "$WF"; then
  note_ok "los 3 jobs (lint, test, deploy) están definidos"
else
  note_fail "faltan uno o más jobs (lint/test/deploy)"
fi

# ---- Check 3: needs chain ----
# test needs lint
if grep -Pzoq '(?s)test:.*?needs:\s*lint' "$WF" 2>/dev/null \
   || awk '/^  test:/{in_t=1} in_t && /needs:[[:space:]]*lint/{print; exit 0} /^  [a-z]/ && !/^  test:/{in_t=0}' "$WF" | grep -q .; then
  note_ok "job 'test' declara needs: lint"
else
  note_fail "job 'test' no declara needs: lint"
fi
# deploy needs test
if awk '/^  deploy:/{in_t=1} in_t && /needs:[[:space:]]*test/{print; exit 0} /^  [a-z]/ && !/^  deploy:/{in_t=0}' "$WF" | grep -q .; then
  note_ok "job 'deploy' declara needs: test"
else
  note_fail "job 'deploy' no declara needs: test"
fi

# ---- Check 4: deploy.if combines event_name push + ref main + needs.test.result ----
deploy_block="$(awk '/^  deploy:/{in_t=1} in_t{print} /^  [a-z]/ && !/^  deploy:/ && NR>1 {if (in_t) exit}' "$WF")"
if echo "$deploy_block" | grep -q "github.event_name == 'push'" \
   && echo "$deploy_block" | grep -q "github.ref == 'refs/heads/main'" \
   && echo "$deploy_block" | grep -q "needs.test.result == 'success'"; then
  note_ok "deploy.if combina event_name=='push', ref=='refs/heads/main' y needs.test.result=='success'"
else
  note_fail "deploy.if no combina las tres condiciones requeridas"
fi

# ---- Check 5: continue-on-error present ----
if grep -q 'continue-on-error:[[:space:]]*true' "$WF"; then
  note_ok "existe al menos un step con continue-on-error: true"
else
  note_fail "no hay ningún step con continue-on-error: true"
fi

# ---- Check 6: if: always() present ----
if grep -Eq 'if:[[:space:]]*\$\{\{[[:space:]]*always\(\)' "$WF"; then
  note_ok "existe un step con if: always()"
else
  note_fail "no hay step con if: always()"
fi

# ---- Check 7: if: failure() present ----
if grep -Eq 'if:[[:space:]]*\$\{\{[[:space:]]*failure\(\)' "$WF"; then
  note_ok "existe un step con if: failure()"
else
  note_fail "no hay step con if: failure()"
fi

# ---- Check 8: env at three levels ----
# workflow-level env (top of file, before 'jobs:')
if awk '/^jobs:/{exit} /^env:/{found=1} END{exit !found}' "$WF"; then
  wf_env=1
else
  wf_env=0
fi
# job-level env (inside at least one job: `    env:` at 4-space indent)
if grep -Eq '^[[:space:]]{4}env:' "$WF"; then
  job_env=1
else
  job_env=0
fi
# step-level env (inside steps: `        env:` at 8-space indent)
if grep -Eq '^[[:space:]]{8}env:' "$WF"; then
  step_env=1
else
  step_env=0
fi
if [ "$wf_env" = 1 ] && [ "$job_env" = 1 ] && [ "$step_env" = 1 ]; then
  note_ok "env: definido a los tres niveles (workflow, job, step)"
else
  note_fail "env: no está definido a los tres niveles (wf=$wf_env job=$job_env step=$step_env)"
fi

# ---- Check 9: actionlint if available ----
if command -v actionlint >/dev/null 2>&1; then
  if actionlint "$WF" >/tmp/actionlint.out 2>&1; then
    note_ok "actionlint sin errores"
  else
    note_fail "actionlint reportó errores (ver /tmp/actionlint.out)"
  fi
else
  note_ok "actionlint no instalado — skip (opcional)"
fi

# ---- Check 10: YAML parses as valid YAML ----
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import sys,yaml; yaml.safe_load(open(sys.argv[1]))" "$WF" 2>/dev/null; then
    note_ok "el workflow es YAML válido"
  else
    note_fail "el workflow no es YAML válido"
  fi
fi

# ---- Check 11: live-mode extras ----
if [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    note_fail "gh CLI no instalado (MODE=live)"
  elif ! gh auth status >/dev/null 2>&1; then
    note_fail "gh no autenticado (MODE=live)"
  elif [ -z "${REPO:-}" ]; then
    note_fail "REPO=<owner/repo> no provisto (MODE=live)"
  else
    latest="$(gh run list -R "$REPO" --workflow conditional.yml --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null || echo '')"
    if [ "$latest" = "success" ]; then
      note_ok "último run de conditional.yml en $REPO = success"
    else
      note_fail "último run de conditional.yml en $REPO = '$latest' (esperado 'success')"
    fi
  fi
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
