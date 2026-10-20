#!/usr/bin/env bash
# Structural validation for gl-08-01-pipeline-with-scanners.
# Checks that .gitlab-ci.yml exists, parses as YAML, declares a 'test' stage,
# has workflow:rules to avoid duplicate pipelines, includes at least 5 native
# security templates, and defines at least one scanner variable. Also checks
# NOTES.md with the required sections.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade real pipeline execution on GitLab SaaS runners.

set -eu

BASE="${1:-/tmp/gl-08-scanners}"
YML="$BASE/.gitlab-ci.yml"
DOC="$BASE/NOTES.md"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

# --- .gitlab-ci.yml ------------------------------------------------------
if [ ! -f "$YML" ]; then
  echo "FAIL: $YML does not exist."
  fail=$((fail+1))
else
  echo "  OK   $YML exists"
  if python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$YML" >/dev/null 2>&1; then
    echo "  OK   $YML is valid YAML"
  else
    echo "  FAIL $YML is not valid YAML"
    fail=$((fail+1))
  fi

  # stages: must mention 'test'
  if grep -qE '^[[:space:]]*-[[:space:]]+test[[:space:]]*$' "$YML"; then
    echo "  OK   declares a 'test' stage"
  else
    echo "  FAIL does not declare a 'test' stage"
    fail=$((fail+1))
  fi

  # workflow: with rules
  if grep -qE '^workflow:' "$YML" && grep -qE '\$CI_PIPELINE_SOURCE|\$CI_OPEN_MERGE_REQUESTS' "$YML"; then
    echo "  OK   has workflow:rules referencing CI_PIPELINE_SOURCE / CI_OPEN_MERGE_REQUESTS"
  else
    echo "  FAIL missing workflow:rules with CI_PIPELINE_SOURCE / CI_OPEN_MERGE_REQUESTS"
    fail=$((fail+1))
  fi

  # Count include:template entries matching known Jobs/*.gitlab-ci.yml
  tpl_count=0
  for tpl in "SAST.gitlab-ci.yml" "Secret-Detection.gitlab-ci.yml" \
             "Dependency-Scanning.gitlab-ci.yml" "Container-Scanning.gitlab-ci.yml" \
             "SAST-IaC.gitlab-ci.yml" "License-Scanning.gitlab-ci.yml" \
             "DAST.gitlab-ci.yml" "Coverage-Fuzzing.gitlab-ci.yml"; do
    if grep -qE "template:[[:space:]]*Jobs/${tpl}" "$YML"; then
      tpl_count=$((tpl_count+1))
    fi
  done
  if [ "$tpl_count" -ge 5 ]; then
    echo "  OK   includes at least 5 security templates (${tpl_count} matched)"
  else
    echo "  FAIL includes only ${tpl_count} security templates (expected >=5)"
    fail=$((fail+1))
  fi

  # At least one scanner-tuning variable
  if grep -qE '^[[:space:]]+(SAST_EXCLUDED_PATHS|DS_EXCLUDED_PATHS|CS_IMAGE|SECURE_LOG_LEVEL):' "$YML"; then
    echo "  OK   defines at least one scanner-tuning variable"
  else
    echo "  FAIL does not define SAST_EXCLUDED_PATHS / DS_EXCLUDED_PATHS / CS_IMAGE / SECURE_LOG_LEVEL"
    fail=$((fail+1))
  fi
fi

# --- NOTES.md ------------------------------------------------------------
if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist."
  fail=$((fail+1))
else
  echo "  OK   $DOC exists"
  for section in "include:template" "Required vs advisory" "Bloqueo por severidad"; do
    if grep -qiF "## " "$DOC" && grep -qiF "$section" "$DOC"; then
      echo "  OK   NOTES.md mentions '${section}'"
    else
      echo "  FAIL NOTES.md missing section mentioning '${section}'"
      fail=$((fail+1))
    fi
  done
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
