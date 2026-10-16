#!/usr/bin/env bash
# Validate helm-04-01-refactor-template-with-helpers.
# Checks: _helpers.tpl defines 6 standard templates; helm template renders 3 resources;
# labels appear on all 3; selectorLabels is a subset (no version).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks pipe
# command output into `grep -q`; grep closing the pipe early produces SIGPIPE
# (exit 141) on the upstream command, which pipefail would spuriously mark as a
# failure.

CHART_DIR="${1:-${CHART_DIR:-/tmp/refactor-helpers}}"
passed=0
failed=0
report=""

fail() { report+="  FAIL — $1\n"; failed=$((failed+1)); }
ok()   { report+="  OK   — $1\n"; passed=$((passed+1)); }

if [ ! -f "$CHART_DIR/Chart.yaml" ]; then
  echo "FAIL: chart not found at $CHART_DIR (expected Chart.yaml)."
  echo "Copy the starter: cp -r starter $CHART_DIR"
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "FAIL: helm CLI not found in PATH."
  exit 1
fi

HELPERS="$CHART_DIR/templates/_helpers.tpl"
if [ ! -f "$HELPERS" ]; then
  fail "_helpers.tpl no existe en templates/"
else
  for name in fastapi-app.name fastapi-app.fullname fastapi-app.chart \
              fastapi-app.labels fastapi-app.selectorLabels fastapi-app.serviceAccountName; do
    if grep -q "define \"$name\"" "$HELPERS"; then
      ok "define \"$name\" presente"
    else
      fail "define \"$name\" ausente en _helpers.tpl"
    fi
  done
fi

RENDER_OUT="$(mktemp)"
if ! helm template demo "$CHART_DIR" > "$RENDER_OUT" 2>&1; then
  fail "helm template demo fallo:"
  report+="$(sed 's/^/    /' "$RENDER_OUT")\n"
else
  ok "helm template demo renderiza sin error"

  for kind in Deployment Service ServiceAccount; do
    if grep -q "^kind: $kind$" "$RENDER_OUT"; then
      ok "render contiene kind: $kind"
    else
      fail "render no contiene kind: $kind"
    fi
  done

  managed_by_count="$(grep -c "app.kubernetes.io/managed-by: Helm" "$RENDER_OUT")"
  if [ "$managed_by_count" -ge 3 ]; then
    ok "label managed-by: Helm presente en >=3 recursos ($managed_by_count)"
  else
    fail "label managed-by: Helm aparece solo $managed_by_count veces (esperado >=3)"
  fi

  if grep -A6 "matchLabels:" "$RENDER_OUT" | grep -q "app.kubernetes.io/version"; then
    fail "selector.matchLabels incluye app.kubernetes.io/version (debe ser subset inmutable)"
  else
    ok "selector.matchLabels NO incluye version (subset inmutable correcto)"
  fi
fi
rm -f "$RENDER_OUT"

echo "== Validacion helm-04-01 sobre $CHART_DIR =="
printf "%b" "$report"
total=$((passed+failed))
echo
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then exit 1; fi
exit 0
