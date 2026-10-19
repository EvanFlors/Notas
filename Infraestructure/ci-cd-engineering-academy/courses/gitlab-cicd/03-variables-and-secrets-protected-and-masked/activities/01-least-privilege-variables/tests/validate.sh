#!/usr/bin/env bash
# Structural validation for gl-03-01-least-privilege-variables.
# Checks that variables.yml and .gitlab-ci.yml exist, parse as YAML, and
# contain the minimum required variables with correct protected/masked
# flags, plus the three jobs with environment: in the pipeline.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real GitLab instance — compare
# manually with solution/.

set -eu

BASE="${1:-/tmp/gl-03-01}"
VARS="$BASE/variables.yml"
CI="$BASE/.gitlab-ci.yml"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

check_file_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
    return 0
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
    return 1
  fi
}

check_yaml_valid() {
  local f="$1"
  if python3 -c "import sys,yaml; yaml.safe_load(open('$f'))" >/dev/null 2>&1; then
    echo "  OK   $f is valid YAML"
    return 0
  else
    echo "  FAIL $f is not valid YAML"
    fail=$((fail+1))
    return 1
  fi
}

# --- variables.yml -------------------------------------------------------
if check_file_exists "$VARS"; then
  check_yaml_valid "$VARS" || true

  # Use a Python helper to inspect fields.
  python3 - "$VARS" <<'PY' > /tmp/gl-03-01-report.txt 2>&1 || true
import sys, yaml
path = sys.argv[1]
try:
    doc = yaml.safe_load(open(path))
except Exception as e:
    print("PYERR", e)
    sys.exit(0)

if not isinstance(doc, dict) or "variables" not in doc or not isinstance(doc["variables"], list):
    print("STRUCT_FAIL: top-level 'variables:' list missing")
    sys.exit(0)

by_name = {}
for v in doc["variables"]:
    if isinstance(v, dict) and "name" in v:
        by_name[v["name"]] = v

required = {
    "INTERNAL_REGISTRY_URL": {"scope": "group", "type": "variable",
                               "protected": False, "masked": False},
    "DOCKER_HUB_READER_TOKEN": {"scope": "group", "type": "variable",
                                 "protected": False, "masked": True},
    "STG_API_KEY": {"scope": "project", "type": "variable",
                     "protected": False, "masked": True,
                     "environment_scope": "staging"},
    "PROD_DEPLOY_ROLE_ARN": {"scope": "project", "type": "variable",
                              "protected": True, "masked": False,
                              "environment_scope": "production"},
    "PROD_API_KEY": {"scope": "project", "type": "variable",
                      "protected": True, "masked": True,
                      "environment_scope": "production"},
    "GCP_SA_JSON": {"scope": "project", "type": "file",
                     "protected": True,
                     "environment_scope": "production"},
}

required_fields = {"name", "scope", "type", "protected", "masked",
                   "example_value", "justification"}

for name, want in required.items():
    if name not in by_name:
        print(f"MISSING {name}")
        continue
    v = by_name[name]
    missing = required_fields - set(v.keys())
    if missing:
        print(f"FIELDS_MISSING {name}: {sorted(missing)}")
        continue
    for k, expected in want.items():
        got = v.get(k)
        if got != expected:
            print(f"FLAG_MISMATCH {name}.{k}: expected={expected!r} got={got!r}")
    print(f"OK {name}")
PY

  while IFS= read -r line; do
    case "$line" in
      "OK "*) echo "  OK   variables.yml entry: ${line#OK }" ;;
      "MISSING "*) echo "  FAIL variables.yml missing required var: ${line#MISSING }"; fail=$((fail+1)) ;;
      "FIELDS_MISSING "*) echo "  FAIL variables.yml fields missing: ${line#FIELDS_MISSING }"; fail=$((fail+1)) ;;
      "FLAG_MISMATCH "*) echo "  FAIL variables.yml flag mismatch: ${line#FLAG_MISMATCH }"; fail=$((fail+1)) ;;
      "STRUCT_FAIL"*) echo "  FAIL variables.yml structural: $line"; fail=$((fail+1)) ;;
      "PYERR"*) echo "  FAIL variables.yml parser error: $line"; fail=$((fail+1)) ;;
    esac
  done < /tmp/gl-03-01-report.txt
fi

# --- .gitlab-ci.yml ------------------------------------------------------
if check_file_exists "$CI"; then
  check_yaml_valid "$CI" || true

  python3 - "$CI" <<'PY' > /tmp/gl-03-01-ci-report.txt 2>&1 || true
import sys, yaml
try:
    doc = yaml.safe_load(open(sys.argv[1]))
except Exception as e:
    print("PYERR", e); sys.exit(0)

if not isinstance(doc, dict):
    print("STRUCT_FAIL: not a mapping"); sys.exit(0)

if "stages" not in doc or not isinstance(doc["stages"], list):
    print("NO_STAGES")
elif "deploy" not in doc["stages"]:
    print("STAGES_NO_DEPLOY")
else:
    print("OK stages")

required_jobs = {
    "deploy-dev":  "development",
    "deploy-stg":  "staging",
    "deploy-prod": "production",
}

for job, env in required_jobs.items():
    if job not in doc:
        print(f"MISSING_JOB {job}")
        continue
    j = doc[job]
    if not isinstance(j, dict):
        print(f"BAD_JOB {job}")
        continue
    e = j.get("environment")
    env_name = e.get("name") if isinstance(e, dict) else (e if isinstance(e, str) else None)
    if env_name != env:
        print(f"ENV_MISMATCH {job}: expected={env!r} got={env_name!r}")
    else:
        print(f"OK {job} env={env}")

    # Check the job references at least one of its expected variables.
    script = j.get("script") or []
    if isinstance(script, str):
        script_text = script
    else:
        script_text = "\n".join(str(x) for x in script)
    expected_refs = {
        "deploy-dev":  ["INTERNAL_REGISTRY_URL"],
        "deploy-stg":  ["STG_API_KEY"],
        "deploy-prod": ["PROD_API_KEY", "PROD_DEPLOY_ROLE_ARN", "GCP_SA_JSON"],
    }
    for ref in expected_refs[job]:
        if ref not in script_text:
            print(f"NO_REF {job}: {ref}")
PY

  while IFS= read -r line; do
    case "$line" in
      "OK "*) echo "  OK   .gitlab-ci.yml: ${line#OK }" ;;
      "NO_STAGES") echo "  FAIL .gitlab-ci.yml missing top-level 'stages:' list"; fail=$((fail+1)) ;;
      "STAGES_NO_DEPLOY") echo "  FAIL .gitlab-ci.yml 'stages:' does not include 'deploy'"; fail=$((fail+1)) ;;
      "MISSING_JOB "*) echo "  FAIL .gitlab-ci.yml missing job: ${line#MISSING_JOB }"; fail=$((fail+1)) ;;
      "BAD_JOB "*) echo "  FAIL .gitlab-ci.yml job not a mapping: ${line#BAD_JOB }"; fail=$((fail+1)) ;;
      "ENV_MISMATCH "*) echo "  FAIL .gitlab-ci.yml environment mismatch: ${line#ENV_MISMATCH }"; fail=$((fail+1)) ;;
      "NO_REF "*) echo "  FAIL .gitlab-ci.yml script missing variable reference: ${line#NO_REF }"; fail=$((fail+1)) ;;
      "STRUCT_FAIL"*) echo "  FAIL .gitlab-ci.yml structural: $line"; fail=$((fail+1)) ;;
      "PYERR"*) echo "  FAIL .gitlab-ci.yml parser error: $line"; fail=$((fail+1)) ;;
    esac
  done < /tmp/gl-03-01-ci-report.txt
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) found."
  echo "        (Semantic correctness in a real GitLab instance is NOT verified here.)"
  exit 1
fi
echo "RESULT: 0 issue(s). Estructura valida. Compara con solution/ para autoevaluacion semantica."
exit 0
