#!/usr/bin/env bash
# Validate gha-08-01-extract-composite-action by parsing the YAML files
# and asserting the composite + refactored workflow are correct.
#
# NOTE: deliberately no `set -o pipefail` because many checks use
# `... | grep -q ...` on long-producing commands which can produce SIGPIPE
# (exit 141) and would be mis-reported as failures.

BASE="${1:-${BASE_DIR:-/tmp/extract-composite}}"

ACTION="$BASE/.github/actions/setup-env/action.yml"
WORKFLOW="$BASE/.github/workflows/ci.yml"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   — $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL — $1\n"; failed=$((failed+1)); }

echo "== Validating gha-08-01 under $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Run starter/bootstrap.sh first." >&2
  exit 1
fi

# ---- Check 1: composite action.yml exists ----
if [ -f "$ACTION" ]; then
  note_ok "composite action.yml existe en .github/actions/setup-env/"
else
  note_fail "no existe $ACTION — crea la composite action"
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $passed/$((passed+failed)) checks OK."
  exit 1
fi

# ---- Check 2: workflow still present ----
if [ -f "$WORKFLOW" ]; then
  note_ok "workflow ci.yml existe"
else
  note_fail "workflow $WORKFLOW no existe (¿lo borraste?)"
fi

# ---- Check 3: python3 + PyYAML available ----
if ! python3 -c 'import yaml' 2>/dev/null; then
  note_fail "python3 con PyYAML requerido. Instala: pip install pyyaml"
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $passed/$((passed+failed)) checks OK."
  exit 1
fi

# ---- Check 4-8: structural YAML checks via python ----
py_result="$(python3 - "$ACTION" "$WORKFLOW" <<'PY'
import sys, yaml

action_path, workflow_path = sys.argv[1], sys.argv[2]

issues = []
ok = []

try:
    with open(action_path) as f:
        act = yaml.safe_load(f)
except Exception as e:
    print(f"FAIL|action.yml no parsea como YAML: {e}")
    sys.exit(0)
ok.append("action.yml parsea como YAML")

runs = act.get("runs") or {}
if runs.get("using") == "composite":
    ok.append("runs.using == 'composite'")
else:
    issues.append(f"runs.using debe ser 'composite' (es: {runs.get('using')!r})")

steps = runs.get("steps") or []
if not isinstance(steps, list) or len(steps) < 2:
    issues.append("runs.steps debe ser una lista con al menos 2 steps")
    steps = []

# Every step with `run:` needs `shell:`
missing_shell = [i for i, s in enumerate(steps) if isinstance(s, dict) and "run" in s and "shell" not in s]
if missing_shell:
    issues.append(f"steps con 'run' sin 'shell' (indices {missing_shell}) — recordatorio: shell: bash es OBLIGATORIO en composite")
else:
    run_steps = [s for s in steps if isinstance(s, dict) and "run" in s]
    if run_steps:
        ok.append(f"todos los {len(run_steps)} steps con 'run' declaran 'shell:'")

# inputs
inputs = act.get("inputs") or {}
pv = inputs.get("python-version") or {}
if str(pv.get("default", "")).strip() == "3.12":
    ok.append("inputs.python-version default == '3.12'")
else:
    issues.append(f"inputs.python-version.default debe ser '3.12' (es: {pv.get('default')!r}) — recuerda las comillas")

poetryv = inputs.get("poetry-version") or {}
if str(poetryv.get("default", "")).strip() == "1.8.3":
    ok.append("inputs.poetry-version default == '1.8.3'")
else:
    issues.append(f"inputs.poetry-version.default debe ser '1.8.3' (es: {poetryv.get('default')!r})")

# output python-path referencing a step
outputs = act.get("outputs") or {}
pp = outputs.get("python-path") or {}
val = str(pp.get("value", ""))
if "steps." in val and ".outputs." in val:
    ok.append("outputs.python-path.value referencia steps.<id>.outputs.<key>")
else:
    issues.append(f"outputs.python-path.value debe referenciar un step: '${{{{ steps.<id>.outputs.<key> }}}}' (es: {val!r})")

# ---- Workflow checks ----
try:
    with open(workflow_path) as f:
        wf = yaml.safe_load(f)
except Exception as e:
    print(f"FAIL|workflow no parsea: {e}")
    for m in ok:   print(f"OK|{m}")
    for m in issues: print(f"FAIL|{m}")
    sys.exit(0)
ok.append("workflow parsea como YAML")

jobs = wf.get("jobs") or {}
expected_jobs = {"lint", "unit", "integration"}
missing = expected_jobs - set(jobs.keys())
if missing:
    issues.append(f"faltan jobs en el workflow: {sorted(missing)}")
else:
    ok.append("workflow conserva jobs: lint, unit, integration")

# Each job uses the composite
for jname in sorted(expected_jobs & set(jobs.keys())):
    job = jobs[jname] or {}
    jsteps = job.get("steps") or []
    uses_composite = any(
        isinstance(s, dict) and str(s.get("uses", "")).strip() == "./.github/actions/setup-env"
        for s in jsteps
    )
    if uses_composite:
        ok.append(f"job '{jname}' invoca ./.github/actions/setup-env")
    else:
        issues.append(f"job '{jname}' NO invoca uses: ./.github/actions/setup-env")

    # No direct poetry setup leftover in workflow (should be inside composite)
    bad_runs = []
    for s in jsteps:
        if isinstance(s, dict) and "run" in s:
            r = str(s["run"])
            if "pip install" in r and "poetry" in r:
                bad_runs.append(r.strip().splitlines()[0])
            elif r.strip().startswith("poetry install"):
                bad_runs.append(r.strip().splitlines()[0])
    if bad_runs:
        issues.append(f"job '{jname}' aún tiene steps 'pip install poetry' / 'poetry install' fuera de la composite: {bad_runs}")

for m in ok:     print(f"OK|{m}")
for m in issues: print(f"FAIL|{m}")
PY
)"

while IFS= read -r line; do
  case "$line" in
    OK\|*)   note_ok   "${line#OK|}" ;;
    FAIL\|*) note_fail "${line#FAIL|}" ;;
  esac
done <<< "$py_result"

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
