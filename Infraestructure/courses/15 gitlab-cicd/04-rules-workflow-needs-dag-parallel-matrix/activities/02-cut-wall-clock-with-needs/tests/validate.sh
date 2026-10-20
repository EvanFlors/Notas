#!/usr/bin/env bash
# Structural validation for gl-04-02-cut-wall-clock-with-needs.
# Checks that .gitlab-ci.yml defines the expected 6 jobs, at least 4 of
# them declare `needs:`, `lint` has explicit `needs: []`, and
# WALL-CLOCK.md documents the comparison with numbers.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness in a real GitLab runner — compare
# manually with solution/.

set -eu

BASE="${1:-/tmp/gl-04-02}"
YML="$BASE/.gitlab-ci.yml"
DOC="$BASE/WALL-CLOCK.md"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

if [ ! -f "$YML" ]; then
  echo "FAIL: $YML does not exist. Student must produce it."
  exit 1
fi
if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# --- 1) YAML parses ------------------------------------------------------
if python3 -c "import yaml,sys; yaml.safe_load(open('$YML'))" 2>/dev/null; then
  echo "  OK   $YML parses as YAML"
else
  echo "  FAIL $YML is not valid YAML"
  exit 1
fi

# --- 2) all 6 required jobs present -------------------------------------
missing=$(python3 - "$YML" <<'PY' 2>/dev/null || echo "ERR"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
expected = ["build-amd64", "build-arm64", "lint", "unit-tests",
            "integration-tests", "deploy-stg"]
missing = [j for j in expected if not isinstance(d.get(j), dict)]
print(",".join(missing) if missing else "NONE")
PY
)
if [ "$missing" = "NONE" ]; then
  echo "  OK   all 6 required jobs are defined"
else
  echo "  FAIL missing jobs: $missing"
  fail=$((fail+1))
fi

# --- 3) at least 4 jobs declare needs: ----------------------------------
needs_count=$(python3 - "$YML" <<'PY' 2>/dev/null || echo "0"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
jobs = ["build-amd64", "build-arm64", "lint", "unit-tests",
        "integration-tests", "deploy-stg"]
c = 0
for j in jobs:
    jd = d.get(j)
    if isinstance(jd, dict) and "needs" in jd:
        c += 1
print(c)
PY
)
if [ "$needs_count" -ge 4 ]; then
  echo "  OK   $needs_count jobs declare 'needs:' (>=4)"
else
  echo "  FAIL only $needs_count jobs declare 'needs:' (expected >=4)"
  fail=$((fail+1))
fi

# --- 4) lint has explicit needs: [] -------------------------------------
lint_shape=$(python3 - "$YML" <<'PY' 2>/dev/null || echo "ERR"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
jd = d.get("lint") or {}
if "needs" not in jd:
    print("ABSENT")
else:
    n = jd.get("needs")
    if isinstance(n, list) and len(n) == 0:
        print("EMPTY")
    else:
        print("NONEMPTY")
PY
)
case "$lint_shape" in
  EMPTY) echo "  OK   lint has explicit needs: []";;
  ABSENT) echo "  FAIL lint is missing explicit 'needs: []'"; fail=$((fail+1));;
  NONEMPTY) echo "  FAIL lint has needs: but it is not empty"; fail=$((fail+1));;
  *) echo "  FAIL could not evaluate lint.needs"; fail=$((fail+1));;
esac

# --- 5) deploy-stg does NOT depend on integration-tests ----------------
deploy_shape=$(python3 - "$YML" <<'PY' 2>/dev/null || echo "ERR"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
jd = d.get("deploy-stg") or {}
needs = jd.get("needs") or []
dep_names = []
for n in needs:
    if isinstance(n, str):
        dep_names.append(n)
    elif isinstance(n, dict) and "job" in n:
        dep_names.append(n["job"])
if not dep_names:
    print("NODEPS")
elif "integration-tests" in dep_names:
    print("DEPENDS_INTEGRATION")
elif "unit-tests" in dep_names:
    print("OK_UNIT_ONLY")
else:
    print("OK_CUSTOM")
PY
)
case "$deploy_shape" in
  OK_UNIT_ONLY|OK_CUSTOM) echo "  OK   deploy-stg.needs reflects a minimal DAG (does not block on integration-tests)";;
  DEPENDS_INTEGRATION) echo "  FAIL deploy-stg depends on integration-tests (defeats the DAG optimization)"; fail=$((fail+1));;
  NODEPS) echo "  FAIL deploy-stg has no 'needs:' at all"; fail=$((fail+1));;
  *) echo "  FAIL could not evaluate deploy-stg.needs"; fail=$((fail+1));;
esac

# --- 6) WALL-CLOCK.md mentions wall clock and key numbers --------------
if grep -qiE 'wall.?clock' "$DOC"; then
  echo "  OK   WALL-CLOCK.md mentions 'wall clock'"
else
  echo "  FAIL WALL-CLOCK.md does not mention 'wall clock'"
  fail=$((fail+1))
fi

if grep -qE '10 ?min|= *10\b' "$DOC"; then
  echo "  OK   WALL-CLOCK.md shows the 10-min figure"
else
  echo "  FAIL WALL-CLOCK.md does not show a '10 min' figure (expected linear total)"
  fail=$((fail+1))
fi

# Must mention linear vs DAG explicitly.
if grep -qiE 'lineal|linear' "$DOC" && grep -qiE 'DAG|needs' "$DOC"; then
  echo "  OK   WALL-CLOCK.md contrasts lineal/linear vs DAG/needs"
else
  echo "  FAIL WALL-CLOCK.md does not clearly contrast lineal vs DAG"
  fail=$((fail+1))
fi

# Must mention the 6 jobs by name.
jobs_mentioned=0
for j in "build-amd64" "build-arm64" "lint" "unit-tests" "integration-tests" "deploy-stg"; do
  if grep -q "$j" "$DOC"; then
    jobs_mentioned=$((jobs_mentioned+1))
  fi
done
if [ "$jobs_mentioned" -ge 5 ]; then
  echo "  OK   WALL-CLOCK.md names at least 5 of the 6 jobs ($jobs_mentioned matched)"
else
  echo "  FAIL WALL-CLOCK.md only names $jobs_mentioned job(s) (expected >=5)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Compare with solution/ for autoevaluation.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/ para autoevaluarte."
exit 0
