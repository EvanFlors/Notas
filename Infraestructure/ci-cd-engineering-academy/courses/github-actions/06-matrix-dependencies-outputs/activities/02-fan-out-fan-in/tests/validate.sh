#!/usr/bin/env bash
# Validate gha-06-02-fan-out-fan-in in MODE=local (default) or MODE=live.
#
# NOTE: deliberately no `set -o pipefail` because some checks use
# `... | grep -q ...` on long-producing commands which can produce SIGPIPE
# (exit 141) and would be mis-reported as failures.

BASE="${1:-${BASE_DIR:-/tmp/gha-06-02}}"
MODE="${MODE:-local}"

LOCAL="$BASE/local"
WF="$LOCAL/.github/workflows/pipeline.yml"
passed=0
failed=0
report=""

note_ok()   { report+="  OK   — $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL — $1\n"; failed=$((failed+1)); }

echo "== Validating ($MODE) under $BASE =="

if [ ! -f "$WF" ]; then
  echo "FAIL: $WF does not exist. Run starter/bootstrap.sh first." >&2
  exit 1
fi

# ---- actionlint if available ----
if command -v actionlint >/dev/null 2>&1; then
  if actionlint "$WF" >/tmp/gha-06-02-actionlint.log 2>&1; then
    note_ok "actionlint pasa sin warnings"
  else
    note_fail "actionlint reporta problemas (ver /tmp/gha-06-02-actionlint.log)"
  fi
else
  note_ok "actionlint no instalado (skip; opcional)"
fi

# ---- Structural checks ----
python3 - "$WF" <<'PY' >/tmp/gha-06-02-struct.log 2>&1
import sys, yaml, re
path = sys.argv[1]
with open(path) as f:
    raw = f.read()
    data = yaml.safe_load(raw)

oks = []
errs = []
def chk(cond, ok_msg, fail_msg):
    (oks if cond else errs).append(ok_msg if cond else fail_msg)

perms = data.get("permissions")
chk(isinstance(perms, dict) and perms.get("contents") == "read",
    "permissions.contents: read a nivel workflow",
    f"permissions.contents debe ser 'read' (actual: {perms!r})")

conc = data.get("concurrency")
if isinstance(conc, dict):
    group = str(conc.get("group", ""))
    chk("github.ref" in group,
        f"concurrency.group incluye github.ref ({group!r})",
        f"concurrency.group debe incluir ${{{{ github.ref }}}} (actual: {group!r})")
    chk(conc.get("cancel-in-progress") is True,
        "concurrency.cancel-in-progress: true",
        f"concurrency.cancel-in-progress debe ser true (actual: {conc.get('cancel-in-progress')!r})")
else:
    errs.append("falta concurrency a nivel workflow")
    errs.append("falta concurrency.cancel-in-progress")

jobs = data.get("jobs") or {}
build = jobs.get("build")
agg   = jobs.get("aggregate")

chk(isinstance(build, dict), "job 'build' presente", "falta job 'build'")
chk(isinstance(agg,   dict), "job 'aggregate' presente", "falta job 'aggregate'")

# --- build matrix ---
if isinstance(build, dict):
    strat = build.get("strategy") or {}
    matrix = strat.get("matrix") or {}
    tgt = matrix.get("target") or []
    chk(isinstance(tgt, list) and len(tgt) >= 3,
        f"build.strategy.matrix.target con {len(tgt)} entradas (>=3)",
        f"build.strategy.matrix.target debe tener >=3 entradas (actual: {tgt!r})")

    outs = build.get("outputs")
    chk(isinstance(outs, dict) and len(outs) >= 1,
        f"build.outputs declara {len(outs) if isinstance(outs, dict) else 0} clave(s)",
        f"build.outputs debe declarar >=1 clave (actual: {outs!r})")

    steps = build.get("steps") or []
    writes_output = False
    for s in steps:
        if isinstance(s, dict):
            run = s.get("run") or ""
            if "$GITHUB_OUTPUT" in run or "GITHUB_OUTPUT" in run:
                writes_output = True
                break
    chk(writes_output,
        "build tiene un step que escribe a $GITHUB_OUTPUT",
        "ningun step de build escribe a $GITHUB_OUTPUT")

# --- aggregate ---
if isinstance(agg, dict):
    needs = agg.get("needs")
    needs_list = [needs] if isinstance(needs, str) else (needs or [])
    chk("build" in needs_list,
        "aggregate.needs incluye 'build'",
        f"aggregate.needs debe incluir 'build' (actual: {needs!r})")

    steps = agg.get("steps") or []
    writes_summary = False
    has_table = False
    for s in steps:
        if isinstance(s, dict):
            run = s.get("run") or ""
            if "$GITHUB_STEP_SUMMARY" in run or "GITHUB_STEP_SUMMARY" in run:
                writes_summary = True
                if "|" in run and re.search(r"\|.*\|", run):
                    has_table = True
    chk(writes_summary,
        "aggregate tiene un step que escribe a $GITHUB_STEP_SUMMARY",
        "ningun step de aggregate escribe a $GITHUB_STEP_SUMMARY")
    chk(has_table,
        "el summary contiene sintaxis de tabla Markdown (lineas con '|')",
        "el summary no parece contener tabla Markdown (lineas con '|')")

# --- pinned actions (@v4 or @v5 at least on checkout/setup-python if present) ---
uses = re.findall(r"uses:\s*([^\s]+)", raw)
if uses:
    ok_pins = all(re.search(r"@v\d+", u) for u in uses)
    chk(ok_pins,
        f"todas las {len(uses)} refs de 'uses:' tienen pin a version (@vN)",
        f"alguna ref de 'uses:' no esta pinneada a version (actual: {uses!r})")
else:
    oks.append("no hay 'uses:' que validar (skip)")

for m in oks: print("STRUCT_OK:", m)
for m in errs: print("STRUCT_FAIL:", m)
sys.exit(1 if errs else 0)
PY
struct_exit=$?

while IFS= read -r line; do
  case "$line" in
    STRUCT_OK:*)   note_ok   "${line#STRUCT_OK: }" ;;
    STRUCT_FAIL:*) note_fail "${line#STRUCT_FAIL: }" ;;
  esac
done < /tmp/gha-06-02-struct.log

if [ "$struct_exit" -ne 0 ] && ! grep -q '^STRUCT_' /tmp/gha-06-02-struct.log; then
  note_fail "YAML no se pudo parsear (ver /tmp/gha-06-02-struct.log)"
fi

# ---- Live mode extras ----
if [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    note_fail "gh CLI no instalado"
  elif ! gh auth status >/dev/null 2>&1; then
    note_fail "gh no autenticado"
  else
    cd "$LOCAL"
    if ! git remote get-url origin >/dev/null 2>&1; then
      note_fail "no hay remote 'origin' configurado"
    else
      conclusion="$(gh run list --workflow=pipeline.yml --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null || echo '')"
      if [ "$conclusion" = "success" ]; then
        note_ok "ultimo run de pipeline.yml concluyo success"
      else
        note_fail "ultimo run de pipeline.yml no es success (actual: '$conclusion')"
      fi
    fi
  fi
elif [ "$MODE" != "local" ]; then
  note_fail "MODE desconocido: '$MODE' (use 'local' o 'live')"
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
