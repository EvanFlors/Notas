#!/usr/bin/env bash
# Validate gha-01-01-first-workflow in MODE=local (default) or MODE=live.
#
# NOTE: deliberately NO `set -o pipefail`. Many checks pipe long-producing
# commands (git log, gh run list) into `grep -q`; pipefail would surface
# spurious SIGPIPE (exit 141) on the producer when grep exits early.

BASE="${1:-${BASE_DIR:-/tmp/gha-01-first-workflow}}"
MODE="${MODE:-local}"
REPO="$BASE/repo"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating gha-01-01-first-workflow ($MODE) under $BASE =="

if [ ! -d "$REPO/.git" ]; then
  echo "FAIL: $REPO no es un repo git. Ejecuta primero starter/bootstrap.sh." >&2
  exit 1
fi

cd "$REPO"

WF_DIR=".github/workflows"
WF_FILE="$WF_DIR/ci.yml"

# ---- Check 1: workflow dir and file exist ----
if [ -d "$WF_DIR" ]; then
  note_ok "Directorio $WF_DIR existe"
else
  note_fail "Directorio $WF_DIR NO existe"
fi

if [ -f "$WF_FILE" ]; then
  note_ok "Archivo $WF_FILE existe"
else
  note_fail "Archivo $WF_FILE NO existe"
fi

# ---- Check 2: structural validation via Python+PyYAML ----
if [ -f "$WF_FILE" ]; then
  struct_output="$(python3 "$SCRIPT_DIR/check_workflow.py" "$WF_FILE" 2>&1)"
  struct_exit=$?
  if [ "$struct_exit" -eq 0 ]; then
    note_ok "Estructura del YAML OK (on:push+pull_request, job con runs-on:ubuntu-*, checkout primero, run con \$GITHUB_*)"
  else
    while IFS= read -r line; do
      case "$line" in
        STRUCT_ISSUE:*|YAML_ERROR:*|STRUCT_ERROR:*)
          note_fail "$line"
          ;;
      esac
    done <<<"$struct_output"
  fi
fi

# ---- Check 3: optional actionlint ----
if command -v actionlint >/dev/null 2>&1; then
  if actionlint "$WF_FILE" >/tmp/.gha-01-actionlint.out 2>&1; then
    note_ok "actionlint sin errores"
  else
    note_fail "actionlint reporto errores (ver /tmp/.gha-01-actionlint.out)"
  fi
else
  report+="  SKIP -- actionlint no instalado (opcional)\n"
fi

# ---- Check 4: at least one commit beyond the base ----
commit_count="$(git rev-list --count main 2>/dev/null || echo 0)"
if [ "$commit_count" -ge 2 ]; then
  note_ok "main tiene $commit_count commits (>=2: base + al menos uno tuyo)"
else
  note_fail "main solo tiene $commit_count commit(s); se esperan >=2"
fi

# ---- Check 5: working tree clean ----
if [ -z "$(git status --porcelain)" ]; then
  note_ok "working tree limpio"
else
  note_fail "working tree sucio (hay cambios no commiteados)"
fi

# ---- Check 6: live-mode only -- gh run completed success ----
if [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    note_fail "gh CLI no instalado"
  elif ! gh auth status >/dev/null 2>&1; then
    note_fail "gh no autenticado"
  else
    recent="$(gh run list --workflow=ci.yml --limit=1 --json databaseId,status,conclusion 2>/dev/null || echo '[]')"
    if [ "$recent" = "[]" ] || [ -z "$recent" ]; then
      echo "  INFO -- no hay runs recientes; disparando gh workflow run ci.yml --ref main"
      gh workflow run ci.yml --ref main >/dev/null 2>&1 || true
      for _ in 1 2 3 4 5 6; do
        sleep 2
        recent="$(gh run list --workflow=ci.yml --limit=1 --json databaseId,status,conclusion 2>/dev/null || echo '[]')"
        [ "$recent" != "[]" ] && break
      done
    fi

    run_id="$(printf '%s' "$recent" | python3 -c "import json,sys; d=json.loads(sys.stdin.read() or '[]'); print(d[0]['databaseId'] if d else '')" 2>/dev/null || echo '')"
    if [ -z "$run_id" ]; then
      note_fail "No se pudo localizar un run reciente de ci.yml. Pusheaste el repo?"
    else
      echo "  INFO -- esperando a que el run $run_id termine (gh run watch)..."
      gh run watch "$run_id" --interval 5 >/dev/null 2>&1 || true
      final="$(gh run view "$run_id" --json status,conclusion -q '.status+"/"+(.conclusion // "")' 2>/dev/null || echo '')"
      if [ "$final" = "completed/success" ]; then
        note_ok "run $run_id termino completed/success"
      else
        note_fail "run $run_id termino $final (esperado completed/success)"
      fi
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
