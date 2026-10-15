#!/usr/bin/env bash
# Validator for gha-13-02-detect-script-injection.
# NOT using `set -o pipefail` — grep -q after long producers can SIGPIPE
# and give false negatives.

BASE="${1:-${BASE_DIR:-/tmp/sec-scanning}}"
PROJECT="$BASE/project"
WF="$PROJECT/.github/workflows/triage.yml"

pass=0
fail=0
report=""

ok()  { report+="  OK   — $1\n"; pass=$((pass+1)); }
bad() { report+="  FAIL — $1\n"; fail=$((fail+1)); }

echo "== Validating script-injection fix under $PROJECT =="

if [ ! -f "$WF" ]; then
  bad "workflow $WF missing (run starter/bootstrap.sh first)"
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi

ok "triage.yml exists"

# ---------- YAML parse + semantic check ----------
verdict="$(python3 - "$WF" <<'PY' 2>&1
import re, sys, yaml

path = sys.argv[1]
raw = open(path).read()
try:
    doc = yaml.safe_load(raw)
except Exception as e:
    print(f"PARSE_ERROR: {e}")
    sys.exit(0)

issues = []

if not isinstance(doc, dict):
    print("PARSE_ERROR: root is not a mapping")
    sys.exit(0)

# Patterns of attacker-controlled contexts that must NEVER appear inside run:
DANGEROUS = re.compile(
    r"\$\{\{\s*github\.(event\.(issue|pull_request|comment|head_commit|workflow_run)"
    r"|actor|head_ref|triggering_actor)"
)

jobs = (doc or {}).get("jobs") or {}
if not jobs:
    issues.append("no jobs defined")

steps_with_run = 0
steps_with_run_using_env_from_event = 0

for jname, jbody in jobs.items():
    if not isinstance(jbody, dict):
        continue
    for i, step in enumerate(jbody.get("steps") or []):
        if not isinstance(step, dict):
            continue
        run = step.get("run")
        if not isinstance(run, str):
            continue
        steps_with_run += 1
        # Strip YAML comments inside the script (lines starting with #)
        lines = [ln for ln in run.splitlines() if not ln.lstrip().startswith("#")]
        script = "\n".join(lines)
        m = DANGEROUS.search(script)
        if m:
            issues.append(
                f"job '{jname}' step #{i} ('{step.get('name','<unnamed>')}'): "
                f"dangerous interpolation inside run: {m.group(0)}"
            )
        env = step.get("env") or {}
        # Does this step receive at least one attacker-controlled context via env?
        for k, v in env.items():
            if isinstance(v, str) and DANGEROUS.search(v):
                steps_with_run_using_env_from_event += 1
                # Check that the script references the env var inside a
                # double-quoted segment (e.g. "...$K..." or "...${K}...").
                quoted = re.compile(
                    rf'"[^"\n]*\$\{{?{re.escape(k)}\}}?[^"\n]*"'
                )
                if not quoted.search(script):
                    issues.append(
                        f"job '{jname}' step #{i}: env var '{k}' is defined "
                        f"but not referenced inside a double-quoted string "
                        f'(expected something like "...$' + k + '...") in run:'
                    )
                break

if steps_with_run_using_env_from_event == 0:
    issues.append(
        "no step uses env: to pass github.event.* / github.actor into run — "
        "expected the hardening pattern"
    )

if issues:
    for i in issues:
        print(f"ISSUE: {i}")
else:
    print("OK")
PY
)"

if printf '%s' "$verdict" | grep -q '^PARSE_ERROR'; then
  bad "triage.yml invalid YAML: $(printf '%s' "$verdict")"
elif printf '%s' "$verdict" | grep -q '^OK$'; then
  ok 'no dangerous ${{ github.* }} interpolation inside any run:'
  ok 'attacker-controlled values pass through env: and are double-quoted'
else
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    bad "$line"
  done <<< "$verdict"
fi

echo
printf "%b" "$report"
echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: ALL CHECKS PASS ($pass/$pass)"
  exit 0
else
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi
