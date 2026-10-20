#!/usr/bin/env bash
# Validate helm-06-01-umbrella-for-dev-stack.
#
# Note: no `set -o pipefail` because several checks pipe `helm template` into
# `grep -q`, which can produce SIGPIPE on helm when grep finds a match early.
# pipefail would spuriously turn those into failures.

CHART="${1:-/tmp/helm06-act01/fastapi-app}"
passed=0
failed=0
report=""

check() {
  local name="$1"; local ok="$2"; local why="${3:-}"
  if [ "$ok" -eq 1 ]; then
    report+="  OK  — $name\n"; passed=$((passed+1))
  else
    report+="  FAIL — $name${why:+ ($why)}\n"; failed=$((failed+1))
  fi
}

command -v helm >/dev/null || { echo "ERROR: helm not installed"; exit 2; }

if [ ! -f "$CHART/Chart.yaml" ]; then
  echo "FAIL: $CHART/Chart.yaml not found. Did you copy the starter and run the activity?"
  exit 1
fi

echo "== Validating $CHART =="

# 1. Chart.yaml declares postgresql dependency
if grep -q "name: postgresql" "$CHART/Chart.yaml" && grep -qE "dependencies:" "$CHART/Chart.yaml"; then
  check "Chart.yaml declares postgresql in dependencies" 1
else
  check "Chart.yaml declares postgresql in dependencies" 0 "no postgresql entry"
fi

# 2. Pinned to exact 18.12.4 (no ^ or ~)
if grep -qE '^\s*version:\s*"?18\.12\.4"?\s*$' "$CHART/Chart.yaml"; then
  check "postgresql pinned to exact version 18.12.4" 1
else
  check "postgresql pinned to exact version 18.12.4" 0 "expected version: \"18.12.4\""
fi

# 3. Chart.lock exists with 18.12.4
if [ -f "$CHART/Chart.lock" ] && grep -q "version: 18.12.4" "$CHART/Chart.lock"; then
  check "Chart.lock pinned to 18.12.4" 1
else
  check "Chart.lock pinned to 18.12.4" 0 "Chart.lock missing or wrong version — run helm dependency update"
fi

# 4. values.yaml default: db.enabled: false
if awk '/^db:/{in_db=1; next} in_db && /^[^ ]/{in_db=0} in_db && /enabled:/{print; exit}' "$CHART/values.yaml" \
     | grep -q "enabled: false"; then
  check "values.yaml defaults db.enabled: false" 1
else
  check "values.yaml defaults db.enabled: false" 0 "db.enabled must default to false (prod-safe)"
fi

# 5. Dev render includes StatefulSet
if [ -f "$CHART/values-dev.yaml" ]; then
  dev_render="$(helm template demo "$CHART" -f "$CHART/values-dev.yaml" 2>/dev/null)"
  if echo "$dev_render" | awk '/^kind:/{print $2}' | grep -qx 'StatefulSet'; then
    check "render with values-dev.yaml includes StatefulSet (postgres)" 1
  else
    check "render with values-dev.yaml includes StatefulSet (postgres)" 0 "dev render has no StatefulSet"
  fi
else
  check "render with values-dev.yaml includes StatefulSet (postgres)" 0 "values-dev.yaml missing"
fi

# 6. Prod render DOES NOT include StatefulSet
if [ -f "$CHART/values-prod.yaml" ]; then
  prod_render="$(helm template demo "$CHART" -f "$CHART/values-prod.yaml" 2>/dev/null)"
  if echo "$prod_render" | awk '/^kind:/{print $2}' | grep -qx 'StatefulSet'; then
    check "render with values-prod.yaml excludes StatefulSet" 0 "prod render still contains StatefulSet"
  else
    check "render with values-prod.yaml excludes StatefulSet" 1
  fi
else
  check "render with values-prod.yaml excludes StatefulSet" 0 "values-prod.yaml missing"
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed/6 checks OK."
[ "$failed" -gt 0 ] && exit 1
exit 0
