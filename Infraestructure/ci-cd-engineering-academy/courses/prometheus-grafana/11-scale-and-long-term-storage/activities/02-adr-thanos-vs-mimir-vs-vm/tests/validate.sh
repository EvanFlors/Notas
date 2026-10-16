#!/usr/bin/env bash
# Validate obs-11-02 (ADR Thanos vs Mimir vs VictoriaMetrics).
# Structural checks only (quality is peer-reviewed):
#   1. ADR file exists
#   2. Length >= 150 lines
#   3. Mentions Thanos, Mimir, VictoriaMetrics, Cortex
#   4. 0 TODO placeholders left
#   5. Contains at least one markdown table (header separator |---|)
#
# Note: we deliberately do NOT enable `set -o pipefail`.

BASE="${1:-${BASE_DIR:-/tmp/obs11-adr}}"
ADR="$BASE/ADR-001-long-term-metrics-store.md"
passed=0
failed=0
report=""

check_1_exists() {
  local name="Check 1 (ADR file en $ADR)"
  if [ -f "$ADR" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — archivo no encontrado\n"; failed=$((failed+1))
  fi
}

check_2_length() {
  local name="Check 2 (longitud >= 150 líneas)"
  if [ ! -f "$ADR" ]; then
    report+="$name: FAIL (ADR ausente)\n"; failed=$((failed+1)); return
  fi
  local n
  n="$(wc -l < "$ADR" | tr -d ' ')"
  if [ "$n" -ge 150 ]; then
    report+="$name: OK ($n líneas)\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — sólo $n líneas (< 150)\n"; failed=$((failed+1))
  fi
}

check_3_mentions() {
  local name="Check 3 (menciona 4 opciones)"
  if [ ! -f "$ADR" ]; then
    report+="$name: FAIL (ADR ausente)\n"; failed=$((failed+1)); return
  fi
  local missing=""
  for word in Thanos Mimir VictoriaMetrics Cortex; do
    if ! grep -q "$word" "$ADR"; then
      missing+=" $word"
    fi
  done
  if [ -z "$missing" ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — faltan menciones a:$missing\n"; failed=$((failed+1))
  fi
}

check_4_no_todos() {
  local name="Check 4 (sin placeholders TODO)"
  if [ ! -f "$ADR" ]; then
    report+="$name: FAIL (ADR ausente)\n"; failed=$((failed+1)); return
  fi
  local todos
  todos="$(grep -c 'TODO' "$ADR" || true)"
  if [ "$todos" -eq 0 ]; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — quedan $todos ocurrencias de 'TODO'\n"; failed=$((failed+1))
  fi
}

check_5_table() {
  local name="Check 5 (contiene al menos una tabla markdown)"
  if [ ! -f "$ADR" ]; then
    report+="$name: FAIL (ADR ausente)\n"; failed=$((failed+1)); return
  fi
  if grep -q '|---' "$ADR" || grep -q '|-------' "$ADR"; then
    report+="$name: OK\n"; passed=$((passed+1))
  else
    report+="$name: FAIL — no se detecta separador de tabla '|---'\n"; failed=$((failed+1))
  fi
}

echo "== Validating obs-11-02 ADR under $BASE =="

check_1_exists
check_2_length
check_3_mentions
check_4_no_todos
check_5_table

echo
printf "%b" "$report"
echo
total=$((passed+failed))
echo "RESULT: $passed/$total checks OK."

if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
