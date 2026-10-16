#!/usr/bin/env bash
# Validate structure of the Platform Contract ADR.
# Checks sections, PromQL blocks, Mermaid blocks, env table.
#
# Note: we do NOT enable `set -o pipefail` because many checks use
# `... | grep -q ...` and grep closing early would mark the upstream as failed.

FILE="${1:-/tmp/argo-12-adr/ADR-001-gitops-contract.md}"
passed=0
failed=0
report=""

if [ ! -f "$FILE" ]; then
  echo "FAIL: ADR file not found at $FILE"
  echo "Hint: cp starter/ADR-template.md /tmp/argo-12-adr/ADR-001-gitops-contract.md"
  exit 1
fi

check() {
  local name="$1"
  local ok="$2"
  local hint="$3"
  if [ "$ok" -eq 1 ]; then
    report+="OK   — $name\n"
    passed=$((passed+1))
  else
    report+="FAIL — $name ($hint)\n"
    failed=$((failed+1))
  fi
}

# 1. Five section headers
for sec in \
  "## 1. Estrategia de promoción" \
  "## 2. PR previews" \
  "## 3. Drift reconciliation" \
  "## 4. Observabilidad" \
  "## 5. IDP flow"; do
  if grep -qF "$sec" "$FILE"; then
    check "sección presente: $sec" 1 ""
  else
    check "sección presente: $sec" 0 "falta el header exacto"
  fi
done

# 2. At least one Mermaid block
mermaid_count=$(grep -c '^```mermaid' "$FILE")
if [ "$mermaid_count" -ge 1 ]; then
  check "al menos un diagrama Mermaid ($mermaid_count encontrados)" 1 ""
else
  check "al menos un diagrama Mermaid" 0 "no se encontró bloque mermaid"
fi

# 3. At least 3 PromQL / expr blocks
promql_count=$(grep -cE '^```promql|^```PromQL' "$FILE")
if [ "$promql_count" -ge 3 ]; then
  check "al menos 3 bloques PromQL ($promql_count encontrados)" 1 ""
else
  check "al menos 3 bloques PromQL" 0 "actualmente $promql_count"
fi

# 4. Environment table (dev / stg / prod rows)
rows_ok=1
for env in '| dev' '| stg' '| prod'; do
  if ! grep -qF "$env" "$FILE"; then rows_ok=0; fi
done
check "tabla con filas dev/stg/prod" "$rows_ok" "falta alguna fila de ambiente"

# 5. Alternativas / Trade-off mentions (at least 2 occurrences each)
alt_count=$(grep -ciE 'Alternativas?' "$FILE")
tro_count=$(grep -ciE 'Trade-?off' "$FILE")
if [ "$alt_count" -ge 2 ]; then
  check "'Alternativas' mencionado $alt_count veces" 1 ""
else
  check "'Alternativas' mencionado al menos 2 veces" 0 "actualmente $alt_count"
fi
if [ "$tro_count" -ge 2 ]; then
  check "'Trade-off' mencionado $tro_count veces" 1 ""
else
  check "'Trade-off' mencionado al menos 2 veces" 0 "actualmente $tro_count"
fi

# 6. Namespace pattern for previews (pr-{number} or similar)
if grep -qE 'pr-\{(number|pr)\}|pr-\{\{number\}\}' "$FILE"; then
  check "nombrado de namespace preview determinista" 1 ""
else
  check "nombrado de namespace preview determinista" 0 "no se encontró patrón 'pr-{number}'"
fi

# 7. Length indicator (>= 120 non-empty lines)
nelines=$(grep -cv '^[[:space:]]*$' "$FILE")
if [ "$nelines" -ge 100 ]; then
  check "longitud razonable ($nelines líneas no-vacías)" 1 ""
else
  check "longitud razonable (>=100 líneas no-vacías)" 0 "actualmente $nelines"
fi

echo "== Validando ADR en $FILE =="
echo
printf "%b" "$report"
echo
echo "RESULT: $passed OK, $failed FAIL."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
