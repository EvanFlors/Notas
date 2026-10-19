#!/usr/bin/env bash
# Structural validation for jk-04-01-extract-shared-library.
#
# Checks that the student produced a Shared Library tree with the canonical
# Jenkins layout (vars/, src/<pkg>/, resources/<pkg>/) plus a consumer
# Jenkinsfile that loads the library pinned to a tag, and a README-INTENT.md
# with the required sections.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT execute Groovy — there is no guaranteed JVM in this environment.
# Semantic validation (does it run on a real Jenkins?) is YOUR responsibility.

set -eu

BASE="${1:-/tmp/jk-04-shared-library}"
LIB="$BASE/acme-ci"
CONSUMER="$BASE/consumer-repo"
DOC="$BASE/README-INTENT.md"
fail=0

echo "== Structural validation for $BASE =="

check_exists() {
  local p="$1"
  local kind="$2"   # 'file' or 'dir'
  if [ "$kind" = "dir" ] && [ -d "$p" ]; then
    echo "  OK   dir  $p"
    return 0
  fi
  if [ "$kind" = "file" ] && [ -f "$p" ]; then
    echo "  OK   file $p"
    return 0
  fi
  echo "  FAIL ${kind} $p does not exist"
  fail=$((fail+1))
  return 1
}

check_contains() {
  local f="$1"
  local needle="$2"
  local label="$3"
  if grep -qE "$needle" "$f" 2>/dev/null; then
    echo "  OK   $(basename "$f"): ${label}"
  else
    echo "  FAIL $f: ${label} (regex: $needle)"
    fail=$((fail+1))
  fi
}

# --- Library tree ---------------------------------------------------------
check_exists "$LIB" dir
check_exists "$LIB/vars" dir
check_exists "$LIB/src/org/acme/ci" dir
check_exists "$LIB/resources/org/acme/ci" dir

STEP="$LIB/vars/standardBuild.groovy"
if check_exists "$STEP" file; then
  check_contains "$STEP" '\bdef[[:space:]]+call\b' "declares 'def call'"
  check_contains "$STEP" 'org\.acme\.ci\.BuildContext|BuildContext' "references BuildContext class"
  check_contains "$STEP" '[Ss]tage' "mentions a stage"
fi

CTX="$LIB/src/org/acme/ci/BuildContext.groovy"
if check_exists "$CTX" file; then
  check_contains "$CTX" '^package[[:space:]]+org\.acme\.ci' "declares 'package org.acme.ci'"
  check_contains "$CTX" '^class[[:space:]]+BuildContext' "declares 'class BuildContext'"
  check_contains "$CTX" 'Serializable' "implements Serializable (required by CPS)"
fi

RES="$LIB/resources/org/acme/ci/pipeline-settings.yaml"
if check_exists "$RES" file; then
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import sys, yaml; yaml.safe_load(open('$RES'))" 2>/dev/null; then
      echo "  OK   pipeline-settings.yaml parses as YAML"
    else
      echo "  FAIL pipeline-settings.yaml is not valid YAML"
      fail=$((fail+1))
    fi
  else
    echo "  SKIP python3 not available — YAML parse check skipped"
  fi
fi

# --- Consumer Jenkinsfile -------------------------------------------------
JF="$CONSUMER/Jenkinsfile"
if check_exists "$JF" file; then
  # Must pin to a tag like @vX.Y.Z, not just @main / @master / unversioned.
  if grep -qE "@Library\\(['\"]acme-ci@v[0-9]+\\.[0-9]+\\.[0-9]+['\"]\\)" "$JF"; then
    echo "  OK   Jenkinsfile pins library to a semver tag (@vX.Y.Z)"
  else
    echo "  FAIL Jenkinsfile does not pin library to a semver tag (expected @Library('acme-ci@vX.Y.Z') _)"
    fail=$((fail+1))
  fi
  # Must invoke standardBuild
  check_contains "$JF" 'standardBuild[[:space:]]*\(' "invokes standardBuild(...)"
  # Must stay small — count non-empty, non-comment lines
  effective=$(grep -cE '^[[:space:]]*[^[:space:]/]' "$JF" || true)
  if [ "$effective" -le 25 ]; then
    echo "  OK   Jenkinsfile is small ($effective non-empty lines, <=25)"
  else
    echo "  FAIL Jenkinsfile has $effective non-empty lines (expected <=25 — delegate to the library)"
    fail=$((fail+1))
  fi
fi

# --- README-INTENT.md -----------------------------------------------------
if check_exists "$DOC" file; then
  for section in "Layout" "Pinning" "Governance"; do
    if grep -qiE "^#+ +.*${section}\b" "$DOC"; then
      echo "  OK   README-INTENT.md has section '${section}'"
    else
      echo "  FAIL README-INTENT.md missing section '${section}'"
      fail=$((fail+1))
    fi
  done
  check_contains "$DOC" 'Serializable' "mentions Serializable"
  check_contains "$DOC" 'JenkinsPipelineUnit' "mentions JenkinsPipelineUnit"
  check_contains "$DOC" 'CODEOWNERS' "mentions CODEOWNERS"
  check_contains "$DOC" 'PR|pull[[:space:]]*request' "mentions PR / pull request"
  check_contains "$DOC" 'tag' "mentions tag (release mechanism)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness on a real Jenkins controller is NOT verified here.)"
  exit 1
fi
echo "OK: Shared Library + consumer Jenkinsfile + README-INTENT.md pasan validacion estructural."
echo "    Compara con solution/ para autoevaluacion."
exit 0
