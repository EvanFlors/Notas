#!/usr/bin/env bash
# Structural validation for jk-03-02-add-manual-gate.
#
# Checks that the Jenkinsfile introduces a manual approval gate with
# input + timeout + submitter, filtered to main branch, followed by a
# Deploy prod stage, and that the pipeline-level post block handles the
# `aborted` path.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT run the pipeline. For real linting, use the pipeline-model-definition
# plugin via `curl $JENKINS_URL/pipeline-model-converter/validate` (see theory
# §10). Semantic correctness: compare manually against solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/jk-03-02}"
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

# --- Baseline Declarative structure (inherited from activity 01) ---------
check_grep '^[[:space:]]*pipeline[[:space:]]*\{'   'top-level `pipeline { }` block'
check_grep '^[[:space:]]*agent[[:space:]]'         '`agent` directive at pipeline level'
check_grep '^[[:space:]]*stages[[:space:]]*\{'     '`stages { }` block'
check_grep '^[[:space:]]*post[[:space:]]*\{'       '`post { }` block'

# --- Manual gate stage ---------------------------------------------------
check_grep "stage\(['\"]Approve prod deploy['\"]\)" "stage('Approve prod deploy') present"
check_grep '\binput[[:space:]]+message[[:space:]]*:'  'input step with `message:` present'
check_grep "ok[[:space:]]*:[[:space:]]*['\"]"        'input step with `ok:` label present'
check_grep "submitter[[:space:]]*:[[:space:]]*['\"]" 'input step restricted via `submitter:`'

# timeout wrapping the input (timeout(time:..., unit:'MINUTES'))
check_grep 'timeout[[:space:]]*\([^)]*unit[[:space:]]*:[[:space:]]*[\"'"'"']MINUTES[\"'"'"']' \
           'input wrapped in timeout(..., unit: \"MINUTES\")'

# when { branch 'main' } somewhere in the file (gate must be branch-gated)
check_grep '^[[:space:]]*when[[:space:]]*\{'       'at least one `when { }` block'
check_grep "branch[[:space:]]+['\"]main['\"]"      '`when { branch \"main\" }` filter present'

# --- Deploy prod stage after the gate ------------------------------------
check_grep "stage\(['\"]Deploy prod['\"]\)"        "stage('Deploy prod') present"

# Order check: 'Approve prod deploy' must appear BEFORE 'Deploy prod'.
line_gate=$(grep -nE "stage\(['\"]Approve prod deploy['\"]\)" "$F" | head -n1 | cut -d: -f1 || true)
line_prod=$(grep -nE "stage\(['\"]Deploy prod['\"]\)" "$F" | head -n1 | cut -d: -f1 || true)
if [ -n "$line_gate" ] && [ -n "$line_prod" ] && [ "$line_gate" -lt "$line_prod" ]; then
  echo "  OK   'Approve prod deploy' stage appears before 'Deploy prod' (line $line_gate < $line_prod)"
else
  echo "  FAIL gate stage must appear before 'Deploy prod' (gate line=$line_gate, prod line=$line_prod)"
  fail=$((fail+1))
fi

# --- post.aborted handling -----------------------------------------------
check_grep '^[[:space:]]*aborted[[:space:]]*\{'    'post.aborted present (gate timeout/cancel handling)'

# --- Optional: declarative-linter via jenkins-cli ------------------------
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
