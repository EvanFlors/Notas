#!/usr/bin/env bash
# Structural validation for jk-03-01-port-gha-workflow-to-jenkinsfile.
#
# Checks that the student's Jenkinsfile contains the Declarative Pipeline
# top-level blocks (pipeline, agent, options, environment, stages, post),
# the expected stage names, a Docker agent on at least one stage, at least
# one `when { }` block, stash/unstash to share workspace, and a credentials
# binding (either `withCredentials` or `credentials('...')`).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT run the pipeline. For real linting, use the pipeline-model-definition
# plugin via `curl $JENKINS_URL/pipeline-model-converter/validate` (see theory
# §10). Semantic correctness: compare manually against solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/jk-03-01}"
F="$BASE/Jenkinsfile"
fail=0

echo "== Structural validation for $F =="

if [ ! -f "$F" ]; then
  echo "FAIL: $F does not exist. Student must produce it."
  exit 1
fi

check_grep() {
  # $1 = pattern (ERE), $2 = label
  local pattern="$1"
  local label="$2"
  if grep -qE "$pattern" "$F"; then
    echo "  OK   $label"
  else
    echo "  FAIL $label  (pattern: $pattern)"
    fail=$((fail+1))
  fi
}

# --- Top-level blocks ----------------------------------------------------
check_grep '^[[:space:]]*pipeline[[:space:]]*\{'          'top-level `pipeline { }` block'
check_grep '^[[:space:]]*agent[[:space:]]+none\b'         '`agent none` at pipeline level'
check_grep '^[[:space:]]*options[[:space:]]*\{'           '`options { }` block'
check_grep 'timeout\s*\('                                 'options.timeout(...) present'
check_grep 'buildDiscarder\s*\('                          'options.buildDiscarder(...) present'
check_grep '^[[:space:]]*environment[[:space:]]*\{'       '`environment { }` block'
check_grep '^\s*APP_NAME\s*='                             'environment defines APP_NAME'
check_grep '^\s*REGISTRY\s*='                             'environment defines REGISTRY'
check_grep '^[[:space:]]*stages[[:space:]]*\{'            '`stages { }` block'
check_grep '^[[:space:]]*post[[:space:]]*\{'              '`post { }` block'
check_grep '^[[:space:]]*always[[:space:]]*\{'            'post.always present'
check_grep '^[[:space:]]*failure[[:space:]]*\{'           'post.failure present'

# --- Required stage names ------------------------------------------------
for stg in 'Checkout' 'Lint' 'Test' 'Build' 'Deploy staging'; do
  check_grep "stage\(['\"]${stg}['\"]\)" "stage('${stg}') present"
done

# --- Agent per stage: at least one docker agent --------------------------
check_grep 'agent[[:space:]]*\{[[:space:]]*docker[[:space:]]*\{' 'at least one stage uses `agent { docker { ... } }`'

# --- Conditional execution -----------------------------------------------
check_grep '^[[:space:]]*when[[:space:]]*\{'              'at least one `when { }` block'
check_grep "branch[[:space:]]+['\"]main['\"]"             '`when { branch "main" }` filter present'

# --- stash / unstash to share workspace ----------------------------------
check_grep '\bstash\b'                                    '`stash` used to share workspace'
check_grep '\bunstash\b'                                  '`unstash` used to share workspace'

# --- Credentials binding (either form) -----------------------------------
if grep -qE 'withCredentials[[:space:]]*\(' "$F" \
   || grep -qE "credentials\(['\"][a-zA-Z0-9_-]+['\"]\)" "$F"; then
  echo "  OK   credentials binding present (withCredentials or credentials('id'))"
else
  echo "  FAIL no credentials binding found (expected withCredentials or credentials('id'))"
  fail=$((fail+1))
fi

# --- Optional: declarative-linter via jenkins-cli ------------------------
# If JENKINS_URL + JENKINS_USER + JENKINS_TOKEN are set, run the real linter.
# Non-blocking: a lint failure counts as an issue, but a network error
# (no Jenkins reachable) is only a warning.
if [ -n "${JENKINS_URL:-}" ] && [ -n "${JENKINS_USER:-}" ] && [ -n "${JENKINS_TOKEN:-}" ]; then
  if command -v curl >/dev/null 2>&1; then
    echo "-- Optional: running declarative-linter against $JENKINS_URL"
    out=$(curl -sf "$JENKINS_URL/pipeline-model-converter/validate" \
           --user "$JENKINS_USER:$JENKINS_TOKEN" \
           -F "jenkinsfile=<$F" 2>/dev/null || true)
    if [ -z "$out" ]; then
      echo "  WARN declarative-linter unreachable (ignored)"
    elif printf '%s' "$out" | grep -qi 'Jenkinsfile successfully validated'; then
      echo "  OK   declarative-linter: Jenkinsfile valid"
    else
      echo "  FAIL declarative-linter rejected the Jenkinsfile:"
      printf '%s\n' "$out" | sed 's/^/        /'
      fail=$((fail+1))
    fi
  fi
else
  echo "-- Optional: skip declarative-linter (JENKINS_URL/USER/TOKEN not set)"
fi

echo
echo "RESULT: $fail issue(s)."
if [ "$fail" -gt 0 ]; then
  echo "        (Semantic correctness is NOT verified; compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: Jenkinsfile pasa validacion estructural."
echo "    Compara con solution/REFERENCE.md para autoevaluacion semantica."
exit 0
