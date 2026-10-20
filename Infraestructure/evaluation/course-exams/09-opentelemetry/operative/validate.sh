#!/usr/bin/env bash
# Validación automática del ejercicio operativo.
# Uso: ./validate.sh  (desde operative/)
set -u

TRACES="out/traces.json"
CONFIG="otel-collector-config.yaml"
FAIL=0

check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "OK   - $label"
  else
    echo "FAIL - $label"
    FAIL=$((FAIL+1))
  fi
}

check "otelcol validate acepta la config" \
  otelcol-contrib validate --config "$CONFIG"

check "existe al menos un span checkout.compute_total" \
  jq -e '[.resourceSpans[].scopeSpans[].spans[] | select(.name=="checkout.compute_total")] | length >= 1' "$TRACES"

check "resource.service.name == checkout" \
  jq -e '[.resourceSpans[].resource.attributes[] | select(.key=="service.name" and .value.stringValue=="checkout")] | length >= 1' "$TRACES"

check "existe un span con status ERROR (code==2)" \
  jq -e '[.resourceSpans[].scopeSpans[].spans[] | select(.status.code==2)] | length >= 1' "$TRACES"

# Este check se invierte: NO debe haber atributos user.email tras el processor.
if jq -e '[.resourceSpans[].scopeSpans[].spans[].attributes[] | select(.key | startswith("user.email"))] | length > 0' "$TRACES" >/dev/null 2>&1; then
  echo "FAIL - atributos user.email NO fueron scrub-eados"
  FAIL=$((FAIL+1))
else
  echo "OK   - atributos user.email ausentes (scrub correcto)"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "$FAIL CHECK(S) FAILED"
  exit 1
fi
