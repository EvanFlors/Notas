#!/usr/bin/env bash
# Structural validation for jk-02-01-first-pipeline-job.
#
# Checks that the Jenkinsfile declares the minimum blocks of a declarative
# pipeline (pipeline / agent / options / stages / stage x>=2 / steps / sh /
# echo / post / buildDiscarder) with balanced braces, and that
# README-INTENT.md carries the four required sections. If docker is
# available and a container named "jenkins" is running on :8080, verifies
# the UI responds. Otherwise marks those two checks as SKIP.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT execute the pipeline nor call the declarative-linter; those are
# optional lab steps.

set -eu

BASE="${1:-/tmp/jk-02-pipeline}"
fail=0
skip=0

echo "== Structural validation for $BASE =="

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

check_token() {
  local f="$1"
  local pattern="$2"
  local label="$3"
  if grep -qE "$pattern" "$f"; then
    echo "  OK   $f: ${label}"
  else
    echo "  FAIL $f: ${label} (pattern: $pattern)"
    fail=$((fail+1))
  fi
}

# --- Jenkinsfile ---------------------------------------------------------
JF="$BASE/Jenkinsfile"
if check_file_exists "$JF"; then
  # Must start the file (ignoring comments/blanks) with "pipeline {"
  first_token=$(grep -vE '^\s*(//|#|/\*|\*|$)' "$JF" | head -1 || true)
  if printf '%s' "$first_token" | grep -qE '^\s*pipeline\s*\{'; then
    echo "  OK   $JF: first non-comment block is 'pipeline {'"
  else
    echo "  FAIL $JF: first non-comment block is not 'pipeline {' (found: $first_token)"
    fail=$((fail+1))
  fi

  check_token "$JF" '(^|[^A-Za-z])agent\s+(any|none|\{)' "declares 'agent'"
  check_token "$JF" '(^|[^A-Za-z])options\s*\{' "has 'options { ... }' block"
  check_token "$JF" 'buildDiscarder\s*\(' "options uses buildDiscarder(...)"
  check_token "$JF" '(^|[^A-Za-z])stages\s*\{' "has 'stages { ... }' block"
  check_token "$JF" '(^|[^A-Za-z])steps\s*\{' "has at least one 'steps { ... }' block"
  check_token "$JF" '(^|[^A-Za-z])post\s*\{' "has 'post { ... }' block"
  check_token "$JF" "(^|[^A-Za-z])sh\s+['\"]" "uses 'sh' step"
  check_token "$JF" "(^|[^A-Za-z])echo\s+['\"]" "uses 'echo' step"

  # Count 'stage(' occurrences — need at least 2.
  stage_count=$(grep -cE "(^|[^A-Za-z])stage\s*\(" "$JF" || true)
  if [ "$stage_count" -ge 2 ]; then
    echo "  OK   $JF: declares at least 2 'stage(...)' (${stage_count} found)"
  else
    echo "  FAIL $JF: declares only ${stage_count} 'stage(...)' (expected >=2)"
    fail=$((fail+1))
  fi

  # Brace balance: strip single-line comments, string literals and block
  # comments as best-effort, then compare counts of '{' and '}'.
  stripped=$(sed -E \
    -e 's#//[^\n]*##g' \
    -e "s/'[^']*'/''/g" \
    -e 's/"[^"]*"/""/g' \
    "$JF" | tr -d '\n')
  open_count=$(printf '%s' "$stripped" | tr -cd '{' | wc -c | tr -d ' ')
  close_count=$(printf '%s' "$stripped" | tr -cd '}' | wc -c | tr -d ' ')
  if [ "$open_count" = "$close_count" ]; then
    echo "  OK   $JF: curly braces balanced ($open_count = $close_count)"
  else
    echo "  FAIL $JF: curly braces NOT balanced (open=$open_count close=$close_count)"
    fail=$((fail+1))
  fi
fi

# --- README-INTENT.md ----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_file_exists "$DOC"; then
  for section in "Pipeline anatomy" "Freestyle vs Pipeline" "Retention" "Run evidence"; do
    if grep -qE "^#+\s+${section}\s*$" "$DOC"; then
      echo "  OK   README-INTENT.md has section '${section}'"
    else
      echo "  FAIL README-INTENT.md missing section '${section}'"
      fail=$((fail+1))
    fi
  done
  # Must mention Jenkinsfile and Git/SCM in the Freestyle-vs-Pipeline rationale.
  if grep -q 'Jenkinsfile' "$DOC"; then
    echo "  OK   README-INTENT.md mentions 'Jenkinsfile'"
  else
    echo "  FAIL README-INTENT.md does not mention 'Jenkinsfile'"
    fail=$((fail+1))
  fi
  if grep -qE '\bGit\b|\bSCM\b' "$DOC"; then
    echo "  OK   README-INTENT.md mentions Git or SCM"
  else
    echo "  FAIL README-INTENT.md does not mention Git or SCM"
    fail=$((fail+1))
  fi
fi

# --- Docker + Jenkins container (optional) -------------------------------
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  if docker ps --format '{{.Names}}' | grep -qx 'jenkins'; then
    echo "  OK   docker container 'jenkins' is running"
    if curl -sfI http://localhost:8080 >/dev/null 2>&1; then
      echo "  OK   Jenkins UI responds on http://localhost:8080"
    else
      echo "  FAIL Jenkins UI does not respond on http://localhost:8080"
      fail=$((fail+1))
    fi
  else
    echo "  SKIP docker is available but no container named 'jenkins' is running"
    skip=$((skip+1))
  fi
else
  echo "  SKIP docker not available — container and UI checks skipped"
  skip=$((skip+2))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s), $skip skipped."
  exit 1
fi
echo "RESULT: 0 issue(s), $skip skipped."
echo "        Pipeline semantic execution and declarative-linter are optional."
exit 0
