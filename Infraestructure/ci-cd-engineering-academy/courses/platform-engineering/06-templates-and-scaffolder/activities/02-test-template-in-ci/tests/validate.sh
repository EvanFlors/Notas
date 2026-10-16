#!/usr/bin/env bash
# Structural validation for plat-06-02-test-template-in-ci.
# Checks:
#   - scripts/regenerate-fixture.sh exists, +x, has set -eu (not pipefail),
#     supports --check, degrades gracefully without cookiecutter.
#   - .github/workflows/template-ci.yaml triggers on PR and runs the script.
#   - Optionally executes the script if cookiecutter is installed.
#
# Note: NO `set -o pipefail` here. Some pipelines (grep | head) short-circuit
# and raise SIGPIPE (141); pipefail would mis-flag them as failure.

set -eu

BASE="${1:-/tmp/plat-06-ci}"
SCRIPT="$BASE/scripts/regenerate-fixture.sh"
WF="$BASE/.github/workflows/template-ci.yaml"
CC_JSON="$BASE/cookiecutter.json"
CC_SKEL="$BASE/cookiecutter-skeleton"
FIXTURE="$BASE/fixture"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Copy the starter first."
  exit 1
fi

# ---- cookiecutter.json & skeleton ----
if [ -f "$CC_JSON" ]; then
  echo "  OK   cookiecutter.json exists"
else
  echo "  FAIL cookiecutter.json missing"
  fail=$((fail+1))
fi

if [ -d "$CC_SKEL" ]; then
  echo "  OK   cookiecutter-skeleton/ exists"
else
  echo "  FAIL cookiecutter-skeleton/ missing"
  fail=$((fail+1))
fi

if [ -d "$FIXTURE" ]; then
  echo "  OK   fixture/ exists"
else
  echo "  FAIL fixture/ missing"
  fail=$((fail+1))
fi

# ---- script ----
if [ ! -f "$SCRIPT" ]; then
  echo "  FAIL $SCRIPT missing"
  fail=$((fail+1))
else
  echo "  OK   scripts/regenerate-fixture.sh exists"

  if [ -x "$SCRIPT" ]; then
    echo "  OK   script is executable"
  else
    echo "  FAIL script is not executable (chmod +x it)"
    fail=$((fail+1))
  fi

  if head -n1 "$SCRIPT" | grep -q '^#!/usr/bin/env bash'; then
    echo "  OK   shebang #!/usr/bin/env bash"
  else
    echo "  FAIL first line must be '#!/usr/bin/env bash'"
    fail=$((fail+1))
  fi

  if grep -qE '^set -eu' "$SCRIPT"; then
    echo "  OK   uses 'set -eu'"
  else
    echo "  FAIL must declare 'set -eu' near the top"
    fail=$((fail+1))
  fi

  if grep -qE '^[[:space:]]*set[[:space:]]+(-o[[:space:]]+pipefail|-eo?[[:space:]]*pipefail)' "$SCRIPT"; then
    echo "  FAIL must NOT use 'set -o pipefail' (SIGPIPE false positives)"
    fail=$((fail+1))
  else
    echo "  OK   does not enable pipefail"
  fi

  if grep -q -- '--check' "$SCRIPT"; then
    echo "  OK   script references --check mode"
  else
    echo "  FAIL script does not implement --check"
    fail=$((fail+1))
  fi

  if grep -qE 'command -v cookiecutter' "$SCRIPT"; then
    echo "  OK   script probes for cookiecutter (graceful SKIP path)"
  else
    echo "  FAIL script does not check for 'cookiecutter' presence"
    fail=$((fail+1))
  fi

  if grep -qE 'trap .* EXIT|rm -rf .*\$\{?STAGE' "$SCRIPT"; then
    echo "  OK   script cleans up temp dirs"
  else
    echo "  FAIL script does not clean up temp dirs (trap or rm)"
    fail=$((fail+1))
  fi
fi

# ---- workflow ----
if [ ! -f "$WF" ]; then
  echo "  FAIL $WF missing"
  fail=$((fail+1))
else
  echo "  OK   workflow template-ci.yaml exists"

  if grep -qE '^on:|^on *:' "$WF" && grep -q 'pull_request' "$WF"; then
    echo "  OK   workflow triggers on pull_request"
  else
    echo "  FAIL workflow must trigger on pull_request"
    fail=$((fail+1))
  fi

  if grep -q 'push' "$WF"; then
    echo "  OK   workflow triggers on push"
  else
    echo "  FAIL workflow must trigger on push (to main)"
    fail=$((fail+1))
  fi

  if grep -q 'actions/checkout' "$WF"; then
    echo "  OK   workflow uses actions/checkout"
  else
    echo "  FAIL workflow missing actions/checkout step"
    fail=$((fail+1))
  fi

  if grep -q 'actions/setup-python' "$WF"; then
    echo "  OK   workflow uses actions/setup-python"
  else
    echo "  FAIL workflow missing actions/setup-python step"
    fail=$((fail+1))
  fi

  if grep -q 'pip install cookiecutter' "$WF"; then
    echo "  OK   workflow installs cookiecutter"
  else
    echo "  FAIL workflow must 'pip install cookiecutter'"
    fail=$((fail+1))
  fi

  if grep -q 'regenerate-fixture.sh --check' "$WF"; then
    echo "  OK   workflow invokes regenerate-fixture.sh --check"
  else
    echo "  FAIL workflow must call 'scripts/regenerate-fixture.sh --check'"
    fail=$((fail+1))
  fi

  # YAML parse
  if python3 -c "import yaml,sys; yaml.safe_load(open('$WF'))" 2>/dev/null; then
    echo "  OK   workflow parses as YAML"
  else
    echo "  FAIL workflow is not valid YAML"
    fail=$((fail+1))
  fi
fi

# ---- Execute the script ----
if [ -x "$SCRIPT" ]; then
  if command -v cookiecutter >/dev/null 2>&1; then
    if bash "$SCRIPT" --check >/dev/null 2>&1; then
      echo "  OK   script --check passes (fixture in sync)"
    else
      echo "  FAIL script --check reports drift or errored"
      fail=$((fail+1))
    fi
  else
    # Even without cookiecutter, the script must exit 0 with SKIP (graceful)
    if out="$(bash "$SCRIPT" --check 2>&1)" && echo "$out" | grep -qi '^SKIP'; then
      echo "  OK   script --check SKIPs gracefully without cookiecutter"
    else
      echo "  FAIL script --check must exit 0 with 'SKIP:' when cookiecutter is missing"
      fail=$((fail+1))
    fi
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Compare with solution/REFERENCE.md for semantic review.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
