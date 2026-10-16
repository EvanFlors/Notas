#!/usr/bin/env bash
# Validate activity helm-07-01-add-migration-hook-with-weight.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# below use `... | grep -q ...`, which can cause the upstream producer (helm,
# kubectl) to receive SIGPIPE (exit 141) once grep finds its first match and
# closes the pipe. pipefail would spuriously fail those checks.

BASE="${1:-${BASE_DIR:-/tmp/helm07-act01}}"
CHART_DIR="$BASE/migration-lab"
NS="helm07-act01"
REL="demo-h7a1"
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

echo "== helm-07-01 validator =="
echo "chart: $CHART_DIR"

# -- Check 1: chart exists --------------------------------------------------
if [ ! -f "$CHART_DIR/Chart.yaml" ]; then
  echo "FAIL: chart not found at $CHART_DIR"
  echo "Hint: cp -r starter/migration-lab $BASE/"
  exit 1
fi
pass "chart found at $CHART_DIR"

# -- Check 2: helm template contains the three hook annotations -------------
RENDER_RAW="$(helm template "$REL" "$CHART_DIR" 2>&1)"
if [ $? -ne 0 ]; then
  fail "helm template failed:"
  report+="$RENDER_RAW\n"
else
  pass "helm template succeeded"
  # Strip YAML comments before checking annotations, so that TODO comments
  # in the starter containing the literal strings do not pass the check.
  RENDER="$(printf '%s\n' "$RENDER_RAW" | sed -E 's/[[:space:]]+#.*$//; s/^#.*$//')"

  if echo "$RENDER" | grep -q '"helm.sh/hook":[[:space:]]*pre-install,pre-upgrade'; then
    pass "helm.sh/hook annotation present and set to pre-install,pre-upgrade"
  else
    fail "helm.sh/hook annotation missing or wrong (expected: pre-install,pre-upgrade)"
  fi

  if echo "$RENDER" | grep -q '"helm.sh/hook-weight":'; then
    pass "helm.sh/hook-weight annotation present"
  else
    fail "helm.sh/hook-weight annotation missing"
  fi

  if echo "$RENDER" | grep -q '"helm.sh/hook-delete-policy":[[:space:]]*before-hook-creation,hook-succeeded'; then
    pass "helm.sh/hook-delete-policy = before-hook-creation,hook-succeeded"
  else
    fail "helm.sh/hook-delete-policy missing or wrong"
  fi
fi

# -- Check 3: install, verify get hooks / get manifest split -----------------
INSTALL_OUT="$(helm install "$REL" "$CHART_DIR" -n "$NS" --create-namespace --wait --timeout 3m $CTX_FLAG 2>&1)"
if [ $? -eq 0 ]; then
  pass "helm install succeeded with --wait"

  MAN="$(helm get manifest "$REL" -n "$NS" $CTX_FLAG 2>/dev/null)"
  HOOKS="$(helm get hooks "$REL" -n "$NS" $CTX_FLAG 2>/dev/null)"

  if echo "$MAN" | grep -q 'migrate-schema'; then
    fail "migrate-schema appears in 'helm get manifest' — it is NOT a hook, it is a regular release resource"
  else
    pass "migrate-schema NOT in 'helm get manifest' (as expected for a hook)"
  fi

  if echo "$HOOKS" | grep -q 'migrate-schema'; then
    pass "migrate-schema appears in 'helm get hooks' (confirmed hook)"
  else
    fail "migrate-schema not listed by 'helm get hooks'"
  fi
else
  fail "helm install failed:"
  report+="$INSTALL_OUT\n"
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed passed / $failed failed"
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
