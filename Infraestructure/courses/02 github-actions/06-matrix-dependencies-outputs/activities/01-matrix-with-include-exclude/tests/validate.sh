#!/usr/bin/env bash
# Validate gha-06-01-matrix-with-include-exclude in MODE=local (default) or MODE=live.
#
# NOTE: deliberately no `set -o pipefail` because some checks use
# `... | grep -q ...` on long-producing commands (git log, gh api) which can
# produce SIGPIPE (exit 141) and would be mis-reported as failures.

BASE="${1:-${BASE_DIR:-/tmp/gha-06-01}}"
MODE="${MODE:-local}"

LOCAL="$BASE/local"
WF="$LOCAL/.github/workflows/ci.yml"
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

# ---- Check: actionlint if available ----
if command -v actionlint >/dev/null 2>&1; then
  if actionlint "$WF" >/tmp/gha-06-01-actionlint.log 2>&1; then
    note_ok "actionlint pasa sin warnings"
  else
    note_fail "actionlint reporta problemas (ver /tmp/gha-06-01-actionlint.log)"
  fi
else
  note_ok "actionlint no instalado (skip; opcional)"
fi

# ---- Structural checks via python3 + yaml ----
python3 - "$WF" <<'PY' >/tmp/gha-06-01-struct.log 2>&1
import sys, yaml
path = sys.argv[1]
with open(path) as f:
    data = yaml.safe_load(f)

errors = []
oks = []

def chk(cond, ok_msg, fail_msg):
    (oks if cond else errors).append(ok_msg if cond else fail_msg)

chk(data.get("name") == "ci",
    "name: ci",
    f"name debe ser 'ci' (actual: {data.get('name')!r})")

# `on` key: PyYAML parses the bareword `on` as True (YAML 1.1 boolean).
on = data.get("on", data.get(True))
if isinstance(on, dict):
    on_keys = set(on.keys())
elif isinstance(on, list):
    on_keys = set(on)
elif isinstance(on, str):
    on_keys = {on}
else:
    on_keys = set()
chk("push" in on_keys and "workflow_dispatch" in on_keys,
    "on: incluye push y workflow_dispatch",
    f"on: debe incluir push Y workflow_dispatch (actual: {sorted(on_keys)})")

perms = data.get("permissions")
chk(isinstance(perms, dict) and perms.get("contents") == "read",
    "permissions.contents: read a nivel workflow",
    f"permissions.contents debe ser 'read' a nivel workflow (actual: {perms!r})")

jobs = data.get("jobs") or {}
test = jobs.get("test")
chk(isinstance(test, dict),
    "job 'test' presente",
    "falta job 'test'")

if isinstance(test, dict):
    chk(test.get("runs-on") == "${{ matrix.os }}",
        "jobs.test.runs-on es ${{ matrix.os }}",
        f"jobs.test.runs-on debe ser '${{{{ matrix.os }}}}' (actual: {test.get('runs-on')!r})")

    strat = test.get("strategy") or {}
    chk(strat.get("fail-fast") is False,
        "strategy.fail-fast: false",
        f"strategy.fail-fast debe ser false (actual: {strat.get('fail-fast')!r})")

    matrix = strat.get("matrix") or {}
    os_list = matrix.get("os") or []
    py_list = matrix.get("python") or []
    chk(isinstance(os_list, list) and len(os_list) >= 2,
        f"matrix.os con {len(os_list)} entradas (>=2)",
        f"matrix.os debe tener >=2 entradas (actual: {os_list!r})")
    chk(isinstance(py_list, list) and len(py_list) >= 2,
        f"matrix.python con {len(py_list)} entradas (>=2)",
        f"matrix.python debe tener >=2 entradas (actual: {py_list!r})")

    exc = matrix.get("exclude") or []
    chk(isinstance(exc, list) and len(exc) >= 1,
        f"matrix.exclude con {len(exc)} entrada(s)",
        "matrix.exclude debe tener >=1 entrada")

    inc = matrix.get("include") or []
    has_exp = any(isinstance(e, dict) and e.get("experimental") is True for e in inc)
    chk(isinstance(inc, list) and len(inc) >= 1 and has_exp,
        f"matrix.include con >=1 entrada y al menos una con experimental: true",
        f"matrix.include debe tener >=1 entrada con experimental: true (actual: {inc!r})")

    steps = test.get("steps") or []
    uses_list = [s.get("uses", "") for s in steps if isinstance(s, dict)]
    chk(any(u.startswith("actions/checkout@v4") for u in uses_list),
        "step actions/checkout@v4 presente",
        "falta step actions/checkout@v4")
    chk(any(u.startswith("actions/setup-python@v5") for u in uses_list),
        "step actions/setup-python@v5 presente",
        "falta step actions/setup-python@v5")

    coe_ok = False
    for s in steps:
        if not isinstance(s, dict):
            continue
        coe = s.get("continue-on-error")
        if isinstance(coe, str) and "matrix.experimental" in coe:
            coe_ok = True
            break
    chk(coe_ok,
        "al menos un step con continue-on-error: ${{ matrix.experimental == true }}",
        "falta step con continue-on-error dinamico referenciando matrix.experimental")

for m in oks:
    print("STRUCT_OK:", m)
for m in errors:
    print("STRUCT_FAIL:", m)
sys.exit(1 if errors else 0)
PY
struct_exit=$?

while IFS= read -r line; do
  case "$line" in
    STRUCT_OK:*)   note_ok   "${line#STRUCT_OK: }" ;;
    STRUCT_FAIL:*) note_fail "${line#STRUCT_FAIL: }" ;;
  esac
done < /tmp/gha-06-01-struct.log

if [ "$struct_exit" -ne 0 ] && ! grep -q '^STRUCT_' /tmp/gha-06-01-struct.log; then
  note_fail "YAML no se pudo parsear (ver /tmp/gha-06-01-struct.log)"
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
      conclusion="$(gh run list --workflow=ci.yml --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null || echo '')"
      if [ "$conclusion" = "success" ]; then
        note_ok "ultimo run de ci.yml concluyo success"
      else
        note_fail "ultimo run de ci.yml no es success (actual: '$conclusion'). Correlo con: gh workflow run ci"
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
