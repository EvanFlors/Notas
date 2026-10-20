#!/usr/bin/env bash
# Structural validation for gl-05-01-extract-component-from-pipeline.
# Checks that the student produced:
#   - component/README.md with the required sections
#   - component/templates/node-test/template.yml with valid 2-doc YAML,
#     a `spec.inputs` block carrying the required inputs, and a job that
#     references $[[ inputs.X ]].
#   - consumer/.gitlab-ci.yml that includes the component with inputs.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# pipe `grep -q` which produces SIGPIPE (exit 141) when grep finds a match
# early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gl-05-01}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

if ! python3 -c "import yaml" >/dev/null 2>&1; then
  echo "FAIL: python3 'yaml' module (PyYAML) is required. Install with: pip install pyyaml"
  exit 2
fi

COMP_README="$BASE/component/README.md"
COMP_TPL="$BASE/component/templates/node-test/template.yml"
CONSUMER="$BASE/consumer/.gitlab-ci.yml"

# --- Presence of required files ------------------------------------------
for f in "$COMP_README" "$COMP_TPL" "$CONSUMER"; do
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
  fi
done

# --- Component README sections -------------------------------------------
if [ -f "$COMP_README" ]; then
  if grep -qi 'node-test' "$COMP_README"; then
    echo "  OK   component/README.md mentions component name 'node-test'"
  else
    echo "  FAIL component/README.md does not mention 'node-test'"
    fail=$((fail+1))
  fi
  if grep -qiE '^#+ +(Uso|Usage)\b' "$COMP_README"; then
    echo "  OK   component/README.md has 'Uso'/'Usage' section"
  else
    echo "  FAIL component/README.md missing 'Uso' or 'Usage' section"
    fail=$((fail+1))
  fi
  if grep -qiE '^#+ +Inputs?\b' "$COMP_README"; then
    echo "  OK   component/README.md has 'Inputs' section"
  else
    echo "  FAIL component/README.md missing 'Inputs' section"
    fail=$((fail+1))
  fi
  if grep -qE 'include:' "$COMP_README" && grep -qE 'component:' "$COMP_README"; then
    echo "  OK   component/README.md shows an include/component usage example"
  else
    echo "  FAIL component/README.md missing an include:component: example"
    fail=$((fail+1))
  fi
fi

# --- Component template.yml: two YAML docs, valid, spec.inputs -----------
if [ -f "$COMP_TPL" ]; then
  tpl_result=$(python3 - "$COMP_TPL" <<'PY'
import sys, yaml
path = sys.argv[1]
try:
    with open(path) as f:
        text = f.read()
    docs = list(yaml.safe_load_all(text))
except yaml.YAMLError as exc:
    print(f"YAML_INVALID:{exc}")
    sys.exit(0)
if len(docs) < 2:
    print(f"ONLY_ONE_DOC:{len(docs)}")
    sys.exit(0)
spec = docs[0]
if not isinstance(spec, dict) or "spec" not in spec or "inputs" not in (spec.get("spec") or {}):
    print("NO_SPEC_INPUTS")
    sys.exit(0)
inputs = spec["spec"]["inputs"] or {}
required = {"node_version", "coverage", "stage"}
missing = required - set(inputs.keys())
if missing:
    print(f"MISSING_INPUTS:{sorted(missing)}")
    sys.exit(0)
# at least one input must have options: or regex: (restriction)
restricted = any(
    isinstance(v, dict) and ("options" in v or "regex" in v)
    for v in inputs.values()
)
if not restricted:
    print("NO_RESTRICTED_INPUT")
    sys.exit(0)
# all inputs must have non-empty description
no_desc = [k for k, v in inputs.items()
           if not isinstance(v, dict) or not str(v.get("description") or "").strip()]
if no_desc:
    print(f"NO_DESCRIPTION:{sorted(no_desc)}")
    sys.exit(0)
# second doc must be a mapping with at least one job using $[[ inputs.X ]]
pipeline = docs[1]
if not isinstance(pipeline, dict) or not pipeline:
    print("PIPELINE_EMPTY")
    sys.exit(0)
pipeline_text = yaml.safe_dump(pipeline)
if "$[[ inputs." not in pipeline_text and "$[[inputs." not in pipeline_text:
    print("NO_INPUT_INTERPOLATION")
    sys.exit(0)
print("OK")
PY
  )
  case "$tpl_result" in
    OK)
      echo "  OK   component/templates/node-test/template.yml: 2 docs, spec.inputs with node_version/coverage/stage, at least one restricted input, all descriptions set, pipeline uses \$[[ inputs.X ]]"
      ;;
    YAML_INVALID:*)
      echo "  FAIL template.yml is not valid YAML: ${tpl_result#YAML_INVALID:}"
      fail=$((fail+1))
      ;;
    ONLY_ONE_DOC:*)
      echo "  FAIL template.yml has only ${tpl_result#ONLY_ONE_DOC:} YAML document(s); expected 2 (spec --- pipeline)"
      fail=$((fail+1))
      ;;
    NO_SPEC_INPUTS)
      echo "  FAIL template.yml first document missing 'spec.inputs'"
      fail=$((fail+1))
      ;;
    MISSING_INPUTS:*)
      echo "  FAIL template.yml missing required inputs: ${tpl_result#MISSING_INPUTS:}"
      fail=$((fail+1))
      ;;
    NO_RESTRICTED_INPUT)
      echo "  FAIL template.yml: no input uses 'options:' or 'regex:' (expected at least one)"
      fail=$((fail+1))
      ;;
    NO_DESCRIPTION:*)
      echo "  FAIL template.yml inputs without 'description:': ${tpl_result#NO_DESCRIPTION:}"
      fail=$((fail+1))
      ;;
    PIPELINE_EMPTY)
      echo "  FAIL template.yml second document (pipeline) is empty"
      fail=$((fail+1))
      ;;
    NO_INPUT_INTERPOLATION)
      echo "  FAIL template.yml pipeline does not use \$[[ inputs.X ]] in any job"
      fail=$((fail+1))
      ;;
    *)
      echo "  FAIL template.yml validation returned unexpected: $tpl_result"
      fail=$((fail+1))
      ;;
  esac
fi

# --- Consumer: includes the component with inputs ------------------------
if [ -f "$CONSUMER" ]; then
  cons_result=$(python3 - "$CONSUMER" <<'PY'
import sys, yaml, re
path = sys.argv[1]
try:
    with open(path) as f:
        data = yaml.safe_load(f)
except yaml.YAMLError as exc:
    print(f"YAML_INVALID:{exc}")
    sys.exit(0)
if not isinstance(data, dict):
    print("NOT_A_MAPPING")
    sys.exit(0)
if "stages" not in data:
    print("NO_STAGES")
    sys.exit(0)
includes = data.get("include")
if not includes:
    print("NO_INCLUDE")
    sys.exit(0)
if isinstance(includes, dict):
    includes = [includes]
if not isinstance(includes, list):
    print("INCLUDE_WRONG_TYPE")
    sys.exit(0)
comp_entry = None
for entry in includes:
    if isinstance(entry, dict) and "component" in entry:
        comp_entry = entry
        break
if not comp_entry:
    print("NO_COMPONENT_ENTRY")
    sys.exit(0)
comp_id = comp_entry.get("component") or ""
# format: <host>/<path>/<name>@<version>
if not re.match(r"^[^/@\s]+/.+/[^/@\s]+@[^\s]+$", comp_id):
    print(f"BAD_COMPONENT_ID:{comp_id}")
    sys.exit(0)
inputs = comp_entry.get("inputs")
if not isinstance(inputs, dict) or len(inputs) < 2:
    print(f"INPUTS_TOO_FEW:{inputs}")
    sys.exit(0)
# must have at least one job besides the include'd ones (any other top-level
# key that is a mapping with 'script' or 'stage' or 'extends')
own_job = False
reserved = {"include", "stages", "variables", "default", "workflow", "image",
            "services", "before_script", "after_script", "cache"}
for k, v in data.items():
    if k in reserved:
        continue
    if isinstance(v, dict) and (
        "script" in v or "stage" in v or "extends" in v or "trigger" in v
    ):
        own_job = True
        break
if not own_job:
    print("NO_OWN_JOB")
    sys.exit(0)
print("OK")
PY
  )
  case "$cons_result" in
    OK)
      echo "  OK   consumer/.gitlab-ci.yml: has stages, includes component with valid id and >=2 inputs, and defines its own job"
      ;;
    YAML_INVALID:*)
      echo "  FAIL consumer/.gitlab-ci.yml is not valid YAML: ${cons_result#YAML_INVALID:}"
      fail=$((fail+1))
      ;;
    NOT_A_MAPPING)
      echo "  FAIL consumer/.gitlab-ci.yml root is not a mapping"
      fail=$((fail+1))
      ;;
    NO_STAGES)
      echo "  FAIL consumer/.gitlab-ci.yml missing top-level 'stages:'"
      fail=$((fail+1))
      ;;
    NO_INCLUDE)
      echo "  FAIL consumer/.gitlab-ci.yml missing 'include:'"
      fail=$((fail+1))
      ;;
    INCLUDE_WRONG_TYPE)
      echo "  FAIL consumer/.gitlab-ci.yml 'include:' is not a list/mapping"
      fail=$((fail+1))
      ;;
    NO_COMPONENT_ENTRY)
      echo "  FAIL consumer/.gitlab-ci.yml include does not use 'component:' entry"
      fail=$((fail+1))
      ;;
    BAD_COMPONENT_ID:*)
      echo "  FAIL consumer/.gitlab-ci.yml component id does not match <host>/<path>/<name>@<version>: ${cons_result#BAD_COMPONENT_ID:}"
      fail=$((fail+1))
      ;;
    INPUTS_TOO_FEW:*)
      echo "  FAIL consumer/.gitlab-ci.yml component entry has fewer than 2 inputs: ${cons_result#INPUTS_TOO_FEW:}"
      fail=$((fail+1))
      ;;
    NO_OWN_JOB)
      echo "  FAIL consumer/.gitlab-ci.yml defines no job of its own (only the included component)"
      fail=$((fail+1))
      ;;
    *)
      echo "  FAIL consumer/.gitlab-ci.yml validation returned unexpected: $cons_result"
      fail=$((fail+1))
      ;;
  esac
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness in a real GitLab is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: componente y consumer pasan validacion estructural."
echo "    Compara con solution/REFERENCE.md para autoevaluacion."
exit 0
