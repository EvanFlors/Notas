#!/usr/bin/env bash
# Structural validation for jk-04-02-write-standard-build-step.
#
# Checks that the student produced a small Shared Library with:
#   vars/standardBuild.groovy      (step with Map args + validation + delegation)
#   src/org/acme/ci/StandardBuild.groovy  (class with Serializable + defaults)
#   resources/org/acme/ci/notify-template.md (template with ${placeholder})
#   Jenkinsfile                    (pins to a semver tag + invokes the step)
#   README-INTENT.md               (API / Defaults / Errores / Versionado)
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT execute Groovy — no JVM is guaranteed in this environment.

set -eu

BASE="${1:-/tmp/jk-04-standard-build}"
fail=0

echo "== Structural validation for $BASE =="

check_exists() {
  local p="$1"
  local kind="$2"
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

# --- Layout ---------------------------------------------------------------
check_exists "$BASE/vars" dir
check_exists "$BASE/src/org/acme/ci" dir
check_exists "$BASE/resources/org/acme/ci" dir

# --- vars/standardBuild.groovy -------------------------------------------
STEP="$BASE/vars/standardBuild.groovy"
if check_exists "$STEP" file; then
  check_contains "$STEP" 'def[[:space:]]+call[[:space:]]*\([[:space:]]*Map' "declares 'def call(Map ...)'"
  check_contains "$STEP" 'org\.acme\.ci\.StandardBuild|StandardBuild' "references StandardBuild class"
  # Argument validation present: assert / IllegalArgumentException / error '...'
  if grep -qE 'assert[[:space:]]+.*image' "$STEP" \
     || grep -qE 'IllegalArgumentException' "$STEP" \
     || grep -qE '\berror[[:space:]]*[("]' "$STEP"; then
    echo "  OK   standardBuild.groovy: validates arguments (assert / IllegalArgumentException / error)"
  else
    echo "  FAIL standardBuild.groovy: no argument validation found (expected assert/IllegalArgumentException/error)"
    fail=$((fail+1))
  fi
  for s in Checkout Build Notify; do
    if grep -qE "stage[[:space:]]*\\([[:space:]]*['\"]${s}['\"]" "$STEP"; then
      echo "  OK   standardBuild.groovy: orchestrates stage '${s}'"
    else
      echo "  FAIL standardBuild.groovy: missing stage '${s}'"
      fail=$((fail+1))
    fi
  done
fi

# --- src/org/acme/ci/StandardBuild.groovy --------------------------------
CLASS="$BASE/src/org/acme/ci/StandardBuild.groovy"
if check_exists "$CLASS" file; then
  check_contains "$CLASS" '^package[[:space:]]+org\.acme\.ci' "declares 'package org.acme.ci'"
  check_contains "$CLASS" '^class[[:space:]]+StandardBuild' "declares 'class StandardBuild'"
  check_contains "$CLASS" 'Serializable' "implements Serializable"
  check_contains "$CLASS" 'String[[:space:]]+image' "declares 'String image'"
  check_contains "$CLASS" 'registry' "declares 'registry'"
  check_contains "$CLASS" 'deploy' "declares 'deploy'"
  # Default for registry present (string literal containing ghcr / registry URL).
  if grep -qE "registry[[:space:]]*=[[:space:]]*['\"]" "$CLASS"; then
    echo "  OK   StandardBuild.groovy: declares a default for 'registry'"
  else
    echo "  FAIL StandardBuild.groovy: no default value for 'registry' (expected  registry = '...')"
    fail=$((fail+1))
  fi
fi

# --- resources/org/acme/ci/notify-template.md ----------------------------
TPL="$BASE/resources/org/acme/ci/notify-template.md"
if check_exists "$TPL" file; then
  if grep -qE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' "$TPL"; then
    echo "  OK   notify-template.md: contains at least one \${placeholder}"
  else
    echo "  FAIL notify-template.md: no \${placeholder} found (expected e.g. \${status}, \${image}, \${buildUrl})"
    fail=$((fail+1))
  fi
fi

# --- Jenkinsfile ----------------------------------------------------------
JF="$BASE/Jenkinsfile"
if check_exists "$JF" file; then
  if grep -qE "@Library\\(['\"]acme-ci@v[0-9]+\\.[0-9]+\\.[0-9]+['\"]\\)" "$JF"; then
    echo "  OK   Jenkinsfile pins library to a semver tag (@vX.Y.Z)"
  else
    echo "  FAIL Jenkinsfile does not pin library to a semver tag (expected @Library('acme-ci@vX.Y.Z') _)"
    fail=$((fail+1))
  fi
  check_contains "$JF" 'standardBuild[[:space:]]*\(' "invokes standardBuild(...)"
  # Count named args passed (lines containing 'word:')
  args=$(grep -cE '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*:' "$JF" || true)
  if [ "$args" -ge 2 ]; then
    echo "  OK   Jenkinsfile passes >=2 named args ($args found)"
  else
    echo "  FAIL Jenkinsfile passes only $args named args (expected >=2)"
    fail=$((fail+1))
  fi
  effective=$(grep -cE '^[[:space:]]*[^[:space:]/]' "$JF" || true)
  if [ "$effective" -le 25 ]; then
    echo "  OK   Jenkinsfile is small ($effective non-empty lines, <=25)"
  else
    echo "  FAIL Jenkinsfile has $effective non-empty lines (expected <=25)"
    fail=$((fail+1))
  fi
fi

# --- README-INTENT.md -----------------------------------------------------
DOC="$BASE/README-INTENT.md"
if check_exists "$DOC" file; then
  for section in "API" "Defaults" "Errores" "Versionado"; do
    if grep -qiE "^#+ +.*${section}\b" "$DOC"; then
      echo "  OK   README-INTENT.md has section '${section}'"
    else
      echo "  FAIL README-INTENT.md missing section '${section}'"
      fail=$((fail+1))
    fi
  done
  check_contains "$DOC" 'Serializable' "mentions Serializable"
  check_contains "$DOC" 'libraryResource' "mentions libraryResource"
  check_contains "$DOC" 'semver|SemVer' "mentions semver"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Semantic correctness on a real Jenkins controller is NOT verified here.)"
  exit 1
fi
echo "OK: standardBuild library + Jenkinsfile + README-INTENT.md pasan validacion estructural."
echo "    Compara con solution/ para autoevaluacion."
exit 0
