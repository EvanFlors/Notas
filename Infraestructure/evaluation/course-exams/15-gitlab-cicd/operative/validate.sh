#!/usr/bin/env bash
# validate.sh — structural validation for GitLab CI/CD exam submission.
# Usage: ./validate.sh <path-to-entrega-dir>
# No GitLab server, no runner, no network. Just YAML parse + grep/yq checks.

set -u

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <entrega-dir>" >&2
  exit 2
fi

ENTREGA="$1"
CI_FILE="$ENTREGA/.gitlab-ci.yml"
JOBS_FILE="$ENTREGA/.gitlab/ci/jobs.yml"
COMPONENT_FILE="$ENTREGA/.gitlab/components/scan/template.yml"

PASS=0
FAIL=0
RED=0
RESULTS=()
RED_FLAGS=()

pass() { RESULTS+=("PASS  $1"); PASS=$((PASS+1)); }
fail() { RESULTS+=("FAIL  $1"); FAIL=$((FAIL+1)); }
flag() { RED_FLAGS+=("RED   $1"); RED=$((RED+1)); }

# --- Pick a YAML parser --------------------------------------------------
YQ_BIN=""
if command -v yq >/dev/null 2>&1; then
  YQ_BIN="yq"
elif python3 -c "import yaml" 2>/dev/null; then
  YQ_BIN="py"
else
  echo "ERROR: need 'yq' or 'python3' with pyyaml installed" >&2
  exit 3
fi

yqget() {
  # yqget <file> <path-expr>
  local file="$1" expr="$2"
  if [[ "$YQ_BIN" == "yq" ]]; then
    yq -r "$expr" "$file" 2>/dev/null
  else
    python3 - "$file" "$expr" <<'PY'
import sys, yaml, json
path, expr = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = yaml.safe_load(f)
# Minimal yq-ish path support: .a.b.c  and  .a[]
cur = data
tokens = [t for t in expr.strip().lstrip('.').split('.') if t]
try:
    for t in tokens:
        if t.endswith('[]'):
            key = t[:-2]
            cur = cur[key] if key else cur
        else:
            cur = cur[t]
    if isinstance(cur, (dict, list)):
        print(json.dumps(cur))
    elif cur is None:
        print("")
    else:
        print(cur)
except Exception:
    print("")
PY
  fi
}

parse_ok() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    return 1
  fi
  if [[ "$YQ_BIN" == "yq" ]]; then
    yq -e '.' "$file" >/dev/null 2>&1
  else
    python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$file" >/dev/null 2>&1
  fi
}

# --- 1. YAML parse -------------------------------------------------------
if parse_ok "$CI_FILE"; then pass "1a .gitlab-ci.yml parses as YAML"
else fail "1a .gitlab-ci.yml missing or invalid YAML"; fi

if parse_ok "$JOBS_FILE"; then pass "1b .gitlab/ci/jobs.yml parses"
else fail "1b .gitlab/ci/jobs.yml missing or invalid"; fi

if parse_ok "$COMPONENT_FILE"; then pass "1c .gitlab/components/scan/template.yml parses"
else fail "1c component template missing or invalid"; fi

# From here on, only run grep/yq checks if the main file parses.
if [[ ! -f "$CI_FILE" ]]; then
  echo "ERROR: $CI_FILE not present — stopping" >&2
  printf '%s\n' "${RESULTS[@]}"
  exit 1
fi

# --- 2. Stages ordering --------------------------------------------------
STAGES_JSON=$(yqget "$CI_FILE" ".stages")
EXPECTED='["build","test","scan","package","deploy"]'
if [[ "$STAGES_JSON" == "$EXPECTED" ]]; then
  pass "2  stages order: build,test,scan,package,deploy"
else
  fail "2  stages order mismatch: got $STAGES_JSON"
fi

# --- 3. workflow rules ---------------------------------------------------
if grep -Eq 'merge_request_event' "$CI_FILE"; then pass "3a workflow allows merge_request_event"
else fail "3a workflow missing merge_request_event rule"; fi
if grep -Eq '\$CI_COMMIT_BRANCH[[:space:]]*==[[:space:]]*"?main"?|\$CI_DEFAULT_BRANCH' "$CI_FILE"; then
  pass "3b workflow references main / default branch"
else
  fail "3b workflow missing main / default branch rule"
fi
if grep -Eq '\[skip ci\]|CI_COMMIT_MESSAGE.*skip ci' "$CI_FILE"; then
  pass "3c workflow blocks [skip ci] messages"
else
  fail "3c workflow does not block [skip ci]"
fi

# --- 4. PYTHON_IMAGE digest pin -----------------------------------------
if grep -Eq 'PYTHON_IMAGE:[[:space:]]*["'\'']?python:3\.12-slim@sha256:[0-9a-f]{8,}' "$CI_FILE"; then
  pass "4  PYTHON_IMAGE pinned by digest"
else
  fail "4  PYTHON_IMAGE missing digest pin (expected python:3.12-slim@sha256:...)"
fi

# --- 5. DAG needs --------------------------------------------------------
# A loose structural check: test_unit and test_lint should list 'build' in needs;
# package should list test_unit (and NOT test_lint).
tu_needs=$(yqget "$CI_FILE" ".test_unit.needs")
tl_needs=$(yqget "$CI_FILE" ".test_lint.needs")
pk_needs=$(yqget "$CI_FILE" ".package.needs")

if echo "$tu_needs" | grep -q 'build'; then pass "5a test_unit needs build"
else fail "5a test_unit does not need build"; fi
if echo "$tl_needs" | grep -q 'build'; then pass "5b test_lint needs build"
else fail "5b test_lint does not need build"; fi
if echo "$pk_needs" | grep -q 'test_unit'; then
  if echo "$pk_needs" | grep -q 'test_lint'; then
    fail "5c package needs test_lint (should only need test_unit)"
  else
    pass "5c package needs test_unit only"
  fi
else
  fail "5c package does not need test_unit"
fi

# --- 6. parallel: matrix in test_unit -----------------------------------
if grep -Eq 'PY_VERSION' "$CI_FILE" && grep -Eq 'SHARD' "$CI_FILE" && grep -Eq 'parallel:' "$CI_FILE"; then
  pass "6  parallel: matrix: with PY_VERSION and SHARD"
else
  fail "6  missing parallel: matrix with PY_VERSION/SHARD"
fi

# --- 7. id_tokens in deploy_prod ----------------------------------------
if grep -Eq 'id_tokens:' "$CI_FILE" && grep -Eq 'aud:[[:space:]]*["'\'']?https://sts\.amazonaws\.com' "$CI_FILE"; then
  pass "7  id_tokens: with aud=https://sts.amazonaws.com present"
else
  fail "7  missing id_tokens / aud for AWS STS"
fi

# --- 8. Review App on_stop ----------------------------------------------
if grep -Eq 'on_stop:[[:space:]]*stop_review' "$CI_FILE"; then
  pass "8a deploy_review declares on_stop: stop_review"
else
  fail "8a deploy_review missing on_stop: stop_review"
fi
if grep -Eq 'action:[[:space:]]*stop' "$CI_FILE"; then
  pass "8b stop_review uses environment:action: stop"
else
  fail "8b missing environment:action: stop"
fi
if grep -Eq 'auto_stop_in:' "$CI_FILE"; then
  pass "8c auto_stop_in present on review env"
else
  fail "8c missing auto_stop_in on review env"
fi

# --- 9. Prod manual ------------------------------------------------------
if grep -Eq 'environment:[[:space:]]*$|name:[[:space:]]*production' "$CI_FILE" && grep -Eq 'when:[[:space:]]*manual' "$CI_FILE"; then
  pass "9  deploy_prod protected (environment production + when: manual)"
else
  fail "9  deploy_prod missing production env or when: manual"
fi

# --- 10. Scanners (>=3 include:template:) --------------------------------
TEMPL_COUNT=$(grep -Ec 'template:[[:space:]]*["'\'']?Jobs/.*\.gitlab-ci\.yml' "$CI_FILE")
if [[ "$TEMPL_COUNT" -ge 3 ]]; then
  pass "10 security templates included: $TEMPL_COUNT (>=3)"
else
  fail "10 only $TEMPL_COUNT security templates (expected >=3)"
fi

# --- 11. Reuse: include local + extends + component ---------------------
if grep -Eq 'include:[[:space:]]*$|local:[[:space:]]*["'\'']?\.gitlab/ci/jobs\.yml' "$CI_FILE"; then
  pass "11a include: local: .gitlab/ci/jobs.yml present"
else
  fail "11a missing include: local: .gitlab/ci/jobs.yml"
fi
if grep -Eq 'extends:[[:space:]]*\.python_defaults|extends:[[:space:]]*\[?\s*\.python_defaults' "$CI_FILE"; then
  pass "11b extends: .python_defaults applied"
else
  fail "11b no job extends .python_defaults"
fi
if [[ -f "$COMPONENT_FILE" ]] && grep -Eq 'spec:' "$COMPONENT_FILE" && grep -Eq 'inputs:' "$COMPONENT_FILE"; then
  pass "11c component declares spec: inputs:"
else
  fail "11c component missing spec: inputs:"
fi

# --- RED FLAGS -----------------------------------------------------------
# only:/except: in new code
if grep -Eq '^[[:space:]]*only:|^[[:space:]]*except:' "$CI_FILE"; then
  flag "only:/except: present (legacy; should use rules:)"
fi
# image: latest or no tag
if grep -Eq 'image:[[:space:]]*["'\'']?[^@:[:space:]]+(:latest)?[[:space:]]*$' "$CI_FILE" \
   | grep -Ev 'sha256:' >/dev/null 2>&1; then
  # separate check for :latest
  :
fi
if grep -Eq 'image:.*:latest' "$CI_FILE"; then
  flag "image: ...:latest present (no pin)"
fi
# curl | bash
if grep -Eq 'curl[^|]+\|[[:space:]]*bash' "$CI_FILE" "$JOBS_FILE" 2>/dev/null; then
  flag "curl | bash from unverified source in scripts"
fi
# privileged true
if grep -Eq 'privileged:[[:space:]]*true' "$CI_FILE"; then
  if ! grep -Eq 'DOCKER_TLS_CERTDIR' "$CI_FILE"; then
    flag "privileged: true without DOCKER_TLS_CERTDIR (DinD unsafe)"
  fi
fi
# AWS access keys literal
if grep -Eq 'AKIA[0-9A-Z]{16}' "$CI_FILE" "$JOBS_FILE" 2>/dev/null; then
  flag "literal AWS access key present"
fi
# secret-looking variables inline
if grep -Eq '^[[:space:]]*(SECRET|TOKEN|PASSWORD|API_KEY)[A-Z_]*:[[:space:]]*["'\'']?[A-Za-z0-9/_+=]{12,}' "$CI_FILE"; then
  flag "secret-looking value inline in variables:"
fi

# --- Report --------------------------------------------------------------
echo "=== CHECKS ==="
printf '%s\n' "${RESULTS[@]}"
echo
if [[ ${#RED_FLAGS[@]} -gt 0 ]]; then
  echo "=== RED FLAGS ==="
  printf '%s\n' "${RED_FLAGS[@]}"
  echo
fi

TOTAL=$((PASS+FAIL))
PCT=0
if [[ $TOTAL -gt 0 ]]; then
  PCT=$(( (PASS*100) / TOTAL ))
fi
echo "=== SCORE ==="
echo "PASS=$PASS  FAIL=$FAIL  RED_FLAGS=$RED  checks=$TOTAL  structural_score=${PCT}%"
echo
echo "NOTE: structural score != final grade. Apply rubric from EXAM.md."
echo "Any red flag reduces the operative section to Insuficiente per rubric."

# Exit 0 if structural >= 60 and no red flags; non-zero otherwise, for scripting.
if [[ $PCT -ge 60 && $RED -eq 0 ]]; then
  exit 0
else
  exit 1
fi
