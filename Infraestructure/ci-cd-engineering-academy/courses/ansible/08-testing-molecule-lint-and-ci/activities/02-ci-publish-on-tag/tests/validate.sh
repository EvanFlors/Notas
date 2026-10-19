#!/usr/bin/env bash
# Structural validation for ans-08-02-ci-publish-on-tag.
# Checks that the student produced a GH Actions workflow with the expected
# jobs (lint, molecule, publish), a reasonable matrix, a tag-gated publish
# step consuming secrets.GALAXY_API_KEY, and a CI-DESIGN.md README with the
# required sections.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/ans-08-02}"
WF="$BASE/.github/workflows/role-ci.yml"
DOC="$BASE/CI-DESIGN.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Create it with 'mkdir -p $BASE/.github/workflows'."
  exit 1
fi

# --- workflow file -------------------------------------------------------
if [ -f "$WF" ]; then
  echo "  OK   workflow file exists: .github/workflows/role-ci.yml"
else
  echo "  FAIL workflow file missing: .github/workflows/role-ci.yml"
  exit 1
fi

# YAML parses?
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import sys,yaml; yaml.safe_load(open(sys.argv[1]))" "$WF" >/dev/null 2>&1; then
    echo "  OK   workflow parses as YAML"
  else
    if file "$WF" 2>/dev/null | grep -qi text; then
      echo "  WARN YAML not parsed (pyyaml missing?) — file is text"
    else
      echo "  FAIL workflow does not parse as YAML"
      fail=$((fail+1))
    fi
  fi
fi

# name:
if grep -qE '^name:' "$WF"; then
  echo "  OK   workflow has top-level 'name:'"
else
  echo "  FAIL workflow is missing top-level 'name:'"
  fail=$((fail+1))
fi

# on: push, pull_request, tags vX.*
if grep -qE '^on:' "$WF"; then
  echo "  OK   workflow declares 'on:'"
else
  echo "  FAIL workflow missing 'on:'"; fail=$((fail+1))
fi
for trig in "push" "pull_request"; do
  if grep -qE "^[[:space:]]+${trig}:" "$WF"; then
    echo "  OK   on.${trig} present"
  else
    echo "  FAIL on.${trig} missing"
    fail=$((fail+1))
  fi
done
if grep -qE "tags:" "$WF" && grep -qE "v\*" "$WF"; then
  echo "  OK   trigger includes tags matching 'v*'"
else
  echo "  FAIL trigger does not include a 'tags: [v*...]' entry"
  fail=$((fail+1))
fi

# three jobs
for job in "lint" "molecule" "publish"; do
  if grep -qE "^[[:space:]]+${job}:" "$WF"; then
    echo "  OK   job '${job}' defined"
  else
    echo "  FAIL job '${job}' is missing"
    fail=$((fail+1))
  fi
done

# needs: lint and needs: molecule
if grep -qE 'needs:[[:space:]]*lint' "$WF"; then
  echo "  OK   molecule declares needs: lint"
else
  echo "  FAIL molecule should declare 'needs: lint'"
  fail=$((fail+1))
fi
if grep -qE 'needs:[[:space:]]*molecule' "$WF"; then
  echo "  OK   publish declares needs: molecule"
else
  echo "  FAIL publish should declare 'needs: molecule'"
  fail=$((fail+1))
fi

# publish gated on tag
if grep -qE "if:[[:space:]]*startsWith\\(github\\.ref,[[:space:]]*'refs/tags/v'\\)" "$WF"; then
  echo "  OK   publish gated by startsWith(github.ref, 'refs/tags/v')"
else
  echo "  FAIL publish is not gated by startsWith(github.ref, 'refs/tags/v')"
  fail=$((fail+1))
fi

# matrix: at least 3 distros + 2 ansible-core versions, fail-fast false
if grep -qE 'fail-fast:[[:space:]]*false' "$WF"; then
  echo "  OK   strategy.fail-fast is false"
else
  echo "  FAIL strategy.fail-fast must be false in a matrix"
  fail=$((fail+1))
fi

# Count geerlingguy entries as a proxy for distros
distros=$(grep -cE 'geerlingguy/docker-.*-ansible' "$WF" || true)
if [ "$distros" -ge 3 ]; then
  echo "  OK   matrix lists at least 3 distros ($distros found)"
else
  echo "  FAIL matrix lists only $distros distros (expected >=3)"
  fail=$((fail+1))
fi

# ansible-core entries like 2.1x.*
ac=$(grep -cE "'2\\.1[0-9]\\." "$WF" || true)
if [ "$ac" -ge 2 ]; then
  echo "  OK   matrix lists at least 2 ansible-core versions ($ac found)"
else
  echo "  FAIL matrix lists only $ac ansible-core versions (expected >=2)"
  fail=$((fail+1))
fi

# secret usage
if grep -qE 'secrets\.GALAXY_API_KEY' "$WF"; then
  echo "  OK   publish uses secrets.GALAXY_API_KEY"
else
  echo "  FAIL publish must consume secrets.GALAXY_API_KEY"
  fail=$((fail+1))
fi

# standard actions
for a in "actions/checkout@v4" "actions/setup-python@v5"; do
  if grep -qE "uses:[[:space:]]*${a}" "$WF"; then
    echo "  OK   uses $a"
  else
    echo "  FAIL does not use $a"
    fail=$((fail+1))
  fi
done

# --- CI-DESIGN.md --------------------------------------------------------
if [ -f "$DOC" ]; then
  echo "  OK   CI-DESIGN.md exists"
  for s in "Matriz" "Gate de publicaci[oó]n" "Secretos" "Cach[eé]"; do
    label="${s%% *}"
    if grep -qiE "^#+ +${s}" "$DOC"; then
      echo "  OK   CI-DESIGN.md has section '${label}'"
    else
      echo "  FAIL CI-DESIGN.md missing section matching '${s}'"
      fail=$((fail+1))
    fi
  done
else
  echo "  FAIL CI-DESIGN.md is missing"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) found."
  exit 1
fi
echo "RESULT: 0 issue(s). Structural validation passed."
exit 0
