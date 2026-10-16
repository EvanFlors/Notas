#!/usr/bin/env bash
# Validate activity helm-07-02-write-helm-test-connection.
#
# Note: no `set -o pipefail`. Several checks pipe helm/kubectl output to grep -q,
# and pipefail would flag SIGPIPE (141) from the producer as a failure.

BASE="${1:-${BASE_DIR:-/tmp/helm07-act02}}"
CHART_DIR="$BASE/wtest-lab"
NS="helm07-act02"
REL="wtest-h7a2"
CTX_FLAG=""
if kubectl config current-context >/dev/null 2>&1; then
  CTX_FLAG="--kube-context=$(kubectl config current-context)"
fi

passed=0
failed=0
report=""

fail() { report+="  FAIL: $1\n"; failed=$((failed+1)); }
pass() { report+="  OK:   $1\n"; passed=$((passed+1)); }

cleanup() {
  helm uninstall "$REL" -n "$NS" $CTX_FLAG >/dev/null 2>&1 || true
  kubectl delete ns "$NS" --wait=true --timeout=90s >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "== helm-07-02 validator =="
echo "chart: $CHART_DIR"

# -- Check 1: chart + test file exist ---------------------------------------
if [ ! -f "$CHART_DIR/Chart.yaml" ]; then
  echo "FAIL: chart not found at $CHART_DIR"
  echo "Hint: cp -r starter/wtest-lab $BASE/"
  exit 1
fi
pass "chart found at $CHART_DIR"

if ls "$CHART_DIR/templates/tests/"*.yaml >/dev/null 2>&1; then
  pass "at least one YAML file in templates/tests/"
else
  fail "no YAML file in $CHART_DIR/templates/tests/ — student has not written test-connection.yaml yet"
fi

# -- Check 2: render includes a test hook -----------------------------------
RENDER="$(helm template "$REL" "$CHART_DIR" --show-only templates/tests/test-connection.yaml 2>/dev/null)"
if [ -z "$RENDER" ]; then
  # fall back to a full render
  RENDER="$(helm template "$REL" "$CHART_DIR" 2>&1)"
fi

if echo "$RENDER" | grep -q '"helm.sh/hook":[[:space:]]*test'; then
  pass "render contains helm.sh/hook: test"
else
  fail "render does NOT contain helm.sh/hook: test"
fi

if echo "$RENDER" | grep -q 'kind:[[:space:]]*Pod'; then
  pass "render contains a Pod"
else
  fail "no Pod in test template (expected kind: Pod)"
fi

# -- Check 3: install + helm test -------------------------------------------
INSTALL_OUT="$(helm install "$REL" "$CHART_DIR" -n "$NS" --create-namespace --wait --timeout 3m $CTX_FLAG 2>&1)"
if [ $? -ne 0 ]; then
  fail "helm install failed:"
  report+="$INSTALL_OUT\n"
else
  pass "helm install succeeded with --wait"

  TEST_OUT="$(helm test "$REL" -n "$NS" $CTX_FLAG 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ] && echo "$TEST_OUT" | grep -q 'Phase:[[:space:]]*Succeeded'; then
    pass "helm test succeeded (Phase: Succeeded)"
  else
    fail "helm test did NOT succeed (rc=$rc)"
    report+="$TEST_OUT\n"
  fi
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed passed / $failed failed"
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
