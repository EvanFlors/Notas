#!/usr/bin/env bash
# Validate helm-04-02-fix-broken-indent.
# Checks: helm template renders OK; resources is a proper nested map; APP_RELEASE
# resolves to the release name; the 4 standard labels are present.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks pipe
# command output into `grep -q`; grep closing the pipe early produces SIGPIPE
# (exit 141) on the upstream command, which pipefail would spuriously mark as a
# failure.

CHART_DIR="${1:-${CHART_DIR:-/tmp/fix-broken-indent}}"
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

RENDER_OUT="$(mktemp)"
if ! helm template demo "$CHART_DIR" > "$RENDER_OUT" 2>&1; then
  fail "helm template demo fallo (quedan bugs sin arreglar):"
  report+="$(sed 's/^/    /' "$RENDER_OUT")\n"
else
  ok "helm template demo renderiza sin error"

  # Check 1: resources: block has requests: and limits: as nested maps under it.
  # We look for the pattern "resources:" followed within ~15 lines by "requests:"
  # at proper indentation (12 spaces) and "limits:" similarly.
  if awk '
      /resources:/ { seen=1; count=0; next }
      seen && count<20 { count++; if (/^ {12}requests:/) req=1; if (/^ {12}limits:/) lim=1 }
      END { exit (req && lim) ? 0 : 1 }
    ' "$RENDER_OUT"; then
    ok "resources: tiene requests y limits bien indentados (12 espacios)"
  else
    fail "resources: no tiene requests/limits a 12 espacios (indent vs nindent?)"
  fi

  # Check 2: APP_RELEASE resolves to the release name "demo".
  if grep -A1 "name: APP_RELEASE" "$RENDER_OUT" | grep -q 'value: "demo"'; then
    ok "APP_RELEASE resuelve al release name (demo)"
  else
    fail "APP_RELEASE no resuelve a 'demo' (scoping en `with` roto?)"
  fi

  # Check 3: 4 standard labels present on metadata.
  labels_ok=1
  for lbl in "helm.sh/chart" "app.kubernetes.io/name" \
             "app.kubernetes.io/instance" "app.kubernetes.io/managed-by"; do
    if ! grep -q "$lbl" "$RENDER_OUT"; then
      labels_ok=0
      fail "label '$lbl' ausente en el render"
    fi
  done
  if [ "$labels_ok" -eq 1 ]; then
    ok "las 4 labels estandar estan presentes"
  fi
fi
rm -f "$RENDER_OUT"

echo "== Validacion helm-04-02 sobre $CHART_DIR =="
printf "%b" "$report"
total=$((passed+failed))
echo
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then exit 1; fi
exit 0
