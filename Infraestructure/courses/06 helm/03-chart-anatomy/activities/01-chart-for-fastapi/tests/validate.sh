#!/usr/bin/env bash
# Validate helm-03-01-chart-for-fastapi.
# Checks: structure, Chart.yaml fields, scaffold trim, helm lint, helm template.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Many checks pipe into
# `grep -q`, which produces SIGPIPE on upstream commands as soon as grep finds
# a match; pipefail would spuriously mark those as failures.

CHART="${1:-${CHART_DIR:-/tmp/helm-03-01/fastapi-app}}"
passed=0
failed=0
report=""

say_ok()   { report+="  OK   $1\n"; passed=$((passed+1)); }
say_fail() { report+="  FAIL $1\n"; failed=$((failed+1)); }

echo "== Validating chart at: $CHART =="

if [ ! -d "$CHART" ]; then
  echo "FAIL: chart directory does not exist: $CHART"
  echo "Hint: solution/run-solution.sh builds it under /tmp/helm-03-01/fastapi-app"
  exit 1
fi

# 1. Chart.yaml present with required keys.
if [ -f "$CHART/Chart.yaml" ]; then
  say_ok "Chart.yaml exists"
  for key in "apiVersion: v2" "name: fastapi-app" "type: application"; do
    if grep -q "^${key}$" "$CHART/Chart.yaml"; then
      say_ok "Chart.yaml has '${key}'"
    else
      say_fail "Chart.yaml missing '${key}'"
    fi
  done
  if grep -qE '^version:[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+' "$CHART/Chart.yaml"; then
    say_ok "Chart.yaml has SemVer version"
  else
    say_fail "Chart.yaml missing/invalid version (SemVer x.y.z)"
  fi
  if grep -qE '^appVersion:' "$CHART/Chart.yaml"; then
    say_ok "Chart.yaml has appVersion"
  else
    say_fail "Chart.yaml missing appVersion"
  fi
else
  say_fail "Chart.yaml does not exist"
fi

# 2. values.yaml present and has expected sections.
if [ -f "$CHART/values.yaml" ]; then
  say_ok "values.yaml exists"
  for section in "image:" "replicaCount:" "service:" "resources:"; do
    if grep -q "^${section}" "$CHART/values.yaml"; then
      say_ok "values.yaml has section '${section}'"
    else
      say_fail "values.yaml missing section '${section}'"
    fi
  done
else
  say_fail "values.yaml does not exist"
fi

# 3. Scaffold trim: forbidden files absent.
for forbidden in templates/hpa.yaml templates/ingress.yaml templates/serviceaccount.yaml; do
  if [ ! -f "$CHART/$forbidden" ]; then
    say_ok "scaffold trimmed: $forbidden absent"
  else
    say_fail "scaffold not trimmed: $forbidden still present"
  fi
done

# 4. Required templates present.
for required in templates/deployment.yaml templates/service.yaml templates/_helpers.tpl; do
  if [ -f "$CHART/$required" ]; then
    say_ok "required file present: $required"
  else
    say_fail "required file missing: $required"
  fi
done

# 5. Helpers used in deployment.yaml.
if [ -f "$CHART/templates/deployment.yaml" ]; then
  if grep -q 'include "fastapi-app.fullname"' "$CHART/templates/deployment.yaml"; then
    say_ok "deployment.yaml uses fastapi-app.fullname helper"
  else
    say_fail "deployment.yaml does not use the fullname helper"
  fi
  if grep -q 'include "fastapi-app.selectorLabels"' "$CHART/templates/deployment.yaml"; then
    say_ok "deployment.yaml uses selectorLabels helper"
  else
    say_fail "deployment.yaml does not use selectorLabels helper"
  fi
fi

# 6. helm lint + helm template (SKIP gracefully if helm absent).
if command -v helm >/dev/null 2>&1; then
  if helm lint "$CHART" >/dev/null 2>&1; then
    say_ok "helm lint passes"
  else
    say_fail "helm lint failed (run: helm lint $CHART)"
  fi

  rendered="$(helm template demo "$CHART" 2>&1)"
  rc=$?
  if [ $rc -eq 0 ]; then
    say_ok "helm template renders without errors"
    if echo "$rendered" | grep -q '^kind: Deployment$'; then
      say_ok "render contains kind: Deployment"
    else
      say_fail "render has no Deployment"
    fi
    if echo "$rendered" | grep -q '^kind: Service$'; then
      say_ok "render contains kind: Service"
    else
      say_fail "render has no Service"
    fi
  else
    say_fail "helm template failed"
  fi
else
  say_ok "helm not installed; SKIP helm lint/template checks (install helm to run them)"
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed check(s) OK, $failed failed."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
