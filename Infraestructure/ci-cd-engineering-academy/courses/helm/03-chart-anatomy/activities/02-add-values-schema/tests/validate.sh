#!/usr/bin/env bash
# Validate helm-03-02-add-values-schema.
# Checks: schema present & valid JSON, structural constraints,
# happy/negative render cases via `helm template`.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# pipe into `grep -q` which triggers SIGPIPE on upstream commands as soon as
# a match is found; pipefail would flag those as failures.

CHART="${1:-${CHART_DIR:-/tmp/helm-03-01/fastapi-app}}"
SCHEMA="$CHART/values.schema.json"
passed=0
failed=0
report=""

say_ok()   { report+="  OK   $1\n"; passed=$((passed+1)); }
say_fail() { report+="  FAIL $1\n"; failed=$((failed+1)); }

echo "== Validating schema at: $SCHEMA =="

if [ ! -d "$CHART" ]; then
  echo "FAIL: chart directory missing: $CHART"
  echo "Hint: build via ../01-chart-for-fastapi/solution/run-solution.sh first."
  exit 1
fi

if [ ! -f "$SCHEMA" ]; then
  echo "FAIL: values.schema.json missing at $SCHEMA"
  exit 1
fi

# 1. Schema is valid JSON.
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import json,sys; json.load(open('$SCHEMA'))" 2>/dev/null; then
    say_ok "values.schema.json is valid JSON"
  else
    say_fail "values.schema.json is NOT valid JSON"
  fi
else
  say_ok "python3 not available; skipping JSON parse check"
fi

# 2. Structural checks (regex-grep on the schema file).
if grep -q 'draft-07/schema' "$SCHEMA"; then
  say_ok 'schema declares $schema draft-07'
else
  say_fail 'schema does not declare $schema draft-07'
fi

if grep -q '"required"' "$SCHEMA" && grep -q '"image"' "$SCHEMA" && grep -q '"service"' "$SCHEMA"; then
  say_ok "schema mentions required image and service"
else
  say_fail "schema missing required image/service"
fi

for enum_val in '"ClusterIP"' '"NodePort"' '"LoadBalancer"' '"Always"' '"IfNotPresent"' '"Never"'; do
  if grep -q "$enum_val" "$SCHEMA"; then
    say_ok "schema contains enum value $enum_val"
  else
    say_fail "schema missing enum value $enum_val"
  fi
done

# 3. Render cases (SKIP gracefully if helm missing).
if command -v helm >/dev/null 2>&1; then
  # Happy cases: must succeed.
  happy_cases=(
    ""
    "--set replicaCount=10"
    "--set image.pullPolicy=Always"
    "--set service.type=NodePort,service.port=30080"
  )
  i=1
  for args in "${happy_cases[@]}"; do
    if helm template demo "$CHART" $args >/dev/null 2>&1; then
      say_ok "happy case H$i rendered OK (args: '${args:-defaults}')"
    else
      say_fail "happy case H$i failed to render (args: '${args:-defaults}')"
    fi
    i=$((i+1))
  done

  # Negative cases: must fail.
  neg_cases=(
    "--set replicaCount=999"
    "--set replicaCount=0"
    "--set image.pullPolicy=Yolo"
    "--set service.type=Mesh"
    "--set service.port=99999"
    '--set image.repository='
  )
  i=1
  for args in "${neg_cases[@]}"; do
    if helm template demo "$CHART" $args >/dev/null 2>&1; then
      say_fail "negative case N$i did NOT fail as expected (args: '$args')"
    else
      say_ok "negative case N$i failed as expected (args: '$args')"
    fi
    i=$((i+1))
  done
else
  say_ok "helm not installed; SKIP render cases (install helm to run them)"
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed check(s) OK, $failed failed."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
