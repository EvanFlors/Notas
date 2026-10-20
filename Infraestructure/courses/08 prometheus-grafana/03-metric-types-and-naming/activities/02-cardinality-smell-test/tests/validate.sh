#!/usr/bin/env bash
# Validate obs-03-02: structure of /tmp/obs03-02/CARDINALITY-ANALYSIS.md.
# Only structure is validated; a human reviewer judges the content.
#
# Note: NOT using `set -o pipefail` because `grep -q` on piped input can trigger
# SIGPIPE and spuriously fail checks.
set -eu

TARGET="${TARGET:-/tmp/obs03-02/CARDINALITY-ANALYSIS.md}"
passed=0
failed=0
report=""

check() {
  local name="$1" ok="$2" why="$3"
  if [ "$ok" -eq 1 ]; then
    report+="OK   — ${name}\n"; passed=$((passed + 1))
  else
    report+="FAIL — ${name}: ${why}\n"; failed=$((failed + 1))
  fi
}

if [ ! -f "$TARGET" ]; then
  echo "FAIL: no existe $TARGET."
  echo "Crea /tmp/obs03-02 y escribe tu análisis allí."
  exit 1
fi

# 1-4: required headers (exact text, start of line)
for header in \
  "## Métricas analizadas" \
  "## Labels de alta cardinalidad" \
  "## Impacto estimado" \
  "## Propuesta de corrección"
do
  has=0
  if grep -Fxq "$header" "$TARGET"; then
    has=1
  fi
  check "header present: '${header}'" "$has" "falta el encabezado de nivel 2 exacto"
done

# 5: at least 3 of the known-bad label names mentioned anywhere
bad_mentions=0
for label in user_id request_id trace_id cache_key query; do
  if grep -q "$label" "$TARGET"; then
    bad_mentions=$((bad_mentions + 1))
  fi
done
if [ "$bad_mentions" -ge 3 ]; then
  check "mentions >= 3 problematic labels" 1 ""
else
  check "mentions >= 3 problematic labels" 0 \
        "sólo mencionas $bad_mentions. Revisa user_id, request_id, trace_id, cache_key, query"
fi

# 6: non-trivial length (> 20 non-empty lines)
nelines=0
# Portable word-count on non-empty lines.
nelines=$(grep -cE '[^[:space:]]' "$TARGET" || true)
if [ "$nelines" -ge 20 ]; then
  check "document has substantive content (>= 20 non-empty lines)" 1 ""
else
  check "document has substantive content (>= 20 non-empty lines)" 0 \
        "sólo $nelines líneas no vacías; amplía el análisis"
fi

echo "== obs-03-02 validation =="
printf "%b" "$report"
echo
echo "RESULT: $passed/6 checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
