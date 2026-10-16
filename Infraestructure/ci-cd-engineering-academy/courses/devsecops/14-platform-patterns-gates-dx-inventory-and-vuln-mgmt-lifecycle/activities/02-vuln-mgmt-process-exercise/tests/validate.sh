#!/usr/bin/env bash
# Structural validation for sec-14-02-vuln-mgmt-process-exercise.
# Checks that VULN-MGMT-PROCESS.md exists and documents the lifecycle stages,
# SLA tiers, metrics with MTTR, end-to-end scenario and antipatterns.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.
set -eu

BASE="${1:-/tmp/sec-14-vulnmgmt}"
DOC="$BASE/VULN-MGMT-PROCESS.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Section headings
if grep -qiE '^#+ *.*(Lifecycle|Ciclo)' "$DOC"; then
  echo "  OK   has 'Lifecycle / Ciclo' section"
else
  echo "  FAIL missing 'Lifecycle / Ciclo' section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *.*(SLA|Tier)' "$DOC"; then
  echo "  OK   has 'SLA / Tier' section"
else
  echo "  FAIL missing 'SLA / Tier' section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *.*(M[eé]tricas|Metrics)' "$DOC"; then
  echo "  OK   has 'Metricas' section"
else
  echo "  FAIL missing 'Metricas' section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *.*(Escenario|Scenario|End-to-end|End to end)' "$DOC"; then
  echo "  OK   has 'Escenario / Scenario' section"
else
  echo "  FAIL missing 'Escenario / Scenario' section"
  fail=$((fail+1))
fi

if grep -qiE '^#+ *.*(Antipatr|Anti-patt|Anti pattern)' "$DOC"; then
  echo "  OK   has 'Antipatrones' section"
else
  echo "  FAIL missing 'Antipatrones' section"
  fail=$((fail+1))
fi

# 6 lifecycle stages mentioned
for stage in "detect" "triage" "prioriti" "remedia" "verif" "report"; do
  if grep -qi "$stage" "$DOC"; then
    echo "  OK   mentions stage '$stage'"
  else
    echo "  FAIL does not mention lifecycle stage '$stage'"
    fail=$((fail+1))
  fi
done

# Tier names
for tier in "Critical" "High" "Medium" "Low"; do
  if grep -q "$tier" "$DOC"; then
    echo "  OK   SLA mentions tier '$tier'"
  else
    echo "  FAIL SLA missing tier '$tier'"
    fail=$((fail+1))
  fi
done

# MTTR must be present
if grep -qi 'MTTR' "$DOC"; then
  echo "  OK   mentions MTTR"
else
  echo "  FAIL does not mention MTTR"
  fail=$((fail+1))
fi

# SLO / SLA numeric: must contain at least one occurrence of a number followed by h or d
if grep -qE '[0-9]+ *(h|d|hours|days)' "$DOC"; then
  echo "  OK   SLA has numeric values (h/d)"
else
  echo "  FAIL SLA does not have numeric values (expected e.g. '24 h', '7 d')"
  fail=$((fail+1))
fi

# SBOM store / query mentioned in scenario
if grep -qiE 'sbom.*store|dependency.?track|guac|inventory|select ' "$DOC"; then
  echo "  OK   scenario references SBOM store / inventory / query"
else
  echo "  FAIL scenario missing SBOM store / inventory / query reference"
  fail=$((fail+1))
fi

# Tabla con al menos 5 pipe-lines (metrics o SLA)
rows=$(grep -cE '^\|' "$DOC")
if [ "$rows" -ge 5 ]; then
  echo "  OK   has at least one table ($rows pipe-lines)"
else
  echo "  FAIL no table found (expected >=5 pipe-lines, found $rows)"
  fail=$((fail+1))
fi

# At least 5 metricas numeradas o en tabla: contamos ocurrencias de SLO
slo_count=$(grep -ciE 'slo|target' "$DOC" || true)
if [ "$slo_count" -ge 3 ]; then
  echo "  OK   mentions SLO/target multiple times ($slo_count)"
else
  echo "  FAIL mentions SLO/target only $slo_count time(s) (expected >=3)"
  fail=$((fail+1))
fi

# Al menos 3 antipatrones numerados o con viñeta
# Buscamos lineas que empiecen con '-' o '*' dentro de 20 lineas despues del heading 'Antipatr'
# Simplificación: contar numeros 1., 2., 3. o viñetas en el documento >= 3
bullets=$(grep -cE '^[[:space:]]*(-|\*|[0-9]+\.) ' "$DOC")
if [ "$bullets" -ge 3 ]; then
  echo "  OK   has at least 3 bulleted/numbered items ($bullets)"
else
  echo "  FAIL has only $bullets bulleted/numbered items (expected >=3)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara VULN-MGMT-PROCESS.md con solution/REFERENCE.md."
exit 0
