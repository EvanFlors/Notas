#!/usr/bin/env bash
# Structural validation for helm-09-02-cover-edge-cases-with-unittest.
# Checks that the student's tests/ directory contains helm-unittest suites
# covering the 5 canonical edge cases.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks use
# `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep finds a
# match early. pipefail would spuriously mark those as failures.
#
# If helm + helm-unittest plugin are present, also runs the suite (opt-in).

BASE="${1:-/tmp/helm-09-02}"
CHART="$BASE/demo-app"
TESTS="$CHART/tests"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -d "$CHART" ]; then
  echo "FAIL: $CHART does not exist. Did you copy the starter?"
  exit 1
fi

if [ ! -d "$TESTS" ]; then
  echo "FAIL: $TESTS does not exist. Create your *_test.yaml files there."
  exit 1
fi

tfiles=$(find "$TESTS" -name '*_test.yaml' | wc -l | tr -d ' ')
if [ "$tfiles" -ge 1 ]; then
  echo "  OK   $tfiles helm-unittest test file(s) present"
else
  echo "  FAIL no *_test.yaml files under $TESTS"
  exit 1
fi

# Combine all tests into one blob for cross-file searches.
BLOB=$(cat "$TESTS"/*_test.yaml 2>/dev/null)

# -------- Required coverage markers --------

# 1. At least 5 'it:' entries
it_count=$(printf '%s\n' "$BLOB" | grep -c '^\s*-\s*it:')
if [ "$it_count" -ge 5 ]; then
  echo "  OK   total 'it:' tests >= 5 ($it_count)"
else
  echo "  FAIL only $it_count 'it:' tests, expected >= 5"
  fail=$((fail+1))
fi

# 2. Empty list edge case: 'set:' block somewhere assigns []
if printf '%s\n' "$BLOB" | grep -qE ':\s*\[\]'; then
  echo "  OK   at least one test sets an empty list ([])"
else
  echo "  FAIL no test exercises an empty list ([]) via 'set:'"
  fail=$((fail+1))
fi

# 3. Nil edge case: either 'isNull' assert or 'set:' with null
if printf '%s\n' "$BLOB" | grep -qE 'isNull|:\s*null\b'; then
  echo "  OK   at least one test exercises nil (isNull or : null)"
else
  echo "  FAIL no test exercises nil (expected 'isNull' assert or ': null' in set:)"
  fail=$((fail+1))
fi

# 4. hasDocuments assert (count: 0 or count: 1)
if printf '%s\n' "$BLOB" | grep -q 'hasDocuments'; then
  echo "  OK   uses hasDocuments assert"
else
  echo "  FAIL no 'hasDocuments' assert found"
  fail=$((fail+1))
fi

# 5. equal assert on an image path
if printf '%s\n' "$BLOB" | grep -qE 'equal' && printf '%s\n' "$BLOB" | grep -qE '\.image|image:'; then
  echo "  OK   has at least one equal assert touching image"
else
  echo "  FAIL no 'equal' assert checking image"
  fail=$((fail+1))
fi

# 6. Boolean flag in set:
if printf '%s\n' "$BLOB" | grep -qE 'enabled:\s*(true|false)'; then
  echo "  OK   at least one test sets a boolean flag (enabled: true/false)"
else
  echo "  FAIL no test uses a boolean flag (expected 'enabled: true' or 'enabled: false' in set:)"
  fail=$((fail+1))
fi

# -------- Opt-in: run helm unittest if plugin is available --------
if command -v helm >/dev/null 2>&1; then
  if helm plugin list 2>/dev/null | grep -q unittest; then
    echo "  INFO running helm unittest (opt-in signal)..."
    if (cd "$BASE" && helm unittest demo-app >/dev/null 2>&1); then
      echo "  OK   helm unittest demo-app passes"
    else
      echo "  WARN helm unittest reports failures — check output manually:"
      echo "       (cd $BASE && helm unittest demo-app)"
    fi
  else
    echo "  WARN helm-unittest plugin NOT installed — structural checks only (SKIP graceful)"
    echo "       install with: helm plugin install https://github.com/helm-unittest/helm-unittest"
  fi
else
  echo "  WARN helm not installed — structural checks only (SKIP graceful)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara con solution/ para autoevaluarte."
exit 0
