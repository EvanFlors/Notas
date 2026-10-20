#!/usr/bin/env bash
# Structural validation for aws-17-03-well-architected-review-and-dr-plan.
# Checks the three deliverables exist and contain the required sections
# and vocabulary covering 6 WA pillars, DR patterns and Cost Explorer flow.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/aws-17-war}"
WAR="$BASE/WELL-ARCHITECTED-REVIEW.md"
DR="$BASE/DR-PLAN.md"
CE="$BASE/COST-EXPLORER-WALKTHROUGH.md"
fail=0

echo "== Structural validation for $BASE =="

for f in "$WAR" "$DR" "$CE"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: $f does not exist. Student must produce it."
    exit 1
  fi
done

# ============================
# WELL-ARCHITECTED-REVIEW.md
# ============================

# Must have Resumen ejecutivo.
if grep -qiE '^#+ *(Resumen|Executive)' "$WAR"; then
  echo "  OK   WAR has Resumen ejecutivo"
else
  echo "  FAIL WAR missing Resumen ejecutivo"
  fail=$((fail+1))
fi

# All 6 pillars must appear.
for p in "Operational Excellence|Excelencia Operacional" \
         "Security|Seguridad" \
         "Reliability|Fiabilidad|Resiliencia" \
         "Performance Efficiency|Rendimiento|Performance" \
         "Cost Optimization|Costos?|Optimizaci[óo]n de Costo" \
         "Sustainability|Sostenibilidad"; do
  if grep -qiE "$p" "$WAR"; then
    echo "  OK   WAR covers pillar: $p"
  else
    echo "  FAIL WAR missing pillar heading matching: $p"
    fail=$((fail+1))
  fi
done

# Must mention HRI or MRI classification.
if grep -qiE '\bHRI\b|\bMRI\b|high risk|medium risk' "$WAR"; then
  echo "  OK   WAR uses risk classification (HRI/MRI)"
else
  echo "  FAIL WAR does not use HRI/MRI classification"
  fail=$((fail+1))
fi

# At least 6 numbered findings or table rows.
rows=$(grep -cE '^\|' "$WAR")
if [ "$rows" -ge 8 ]; then
  echo "  OK   WAR has at least a 6-finding table ($rows pipe-lines)"
else
  echo "  FAIL WAR has only $rows pipe-lines (expected a 6-row table => >=8)"
  fail=$((fail+1))
fi

# Must mention the workload orders-platform (or similar).
if grep -qi 'orders-platform\|workload' "$WAR"; then
  echo "  OK   WAR names the workload"
else
  echo "  FAIL WAR does not name the workload"
  fail=$((fail+1))
fi

# ============================
# DR-PLAN.md
# ============================

# Must have at least 3 workloads mentioned.
wl=0
for w in "checkout" "payments" "catalog" "batch" "redshift"; do
  if grep -qi "$w" "$DR"; then
    wl=$((wl+1))
  fi
done
if [ "$wl" -ge 3 ]; then
  echo "  OK   DR-PLAN names at least 3 workloads ($wl found)"
else
  echo "  FAIL DR-PLAN names only $wl workloads (expected >=3)"
  fail=$((fail+1))
fi

# Must mention at least 2 DR patterns.
patt=0
for p in "backup.*restore|backup-restore|backup/restore" \
         "pilot.?light" \
         "warm.?standby" \
         "active-active|activo-activo"; do
  if grep -qiE "$p" "$DR"; then
    patt=$((patt+1))
  fi
done
if [ "$patt" -ge 2 ]; then
  echo "  OK   DR-PLAN mentions at least 2 DR patterns ($patt found)"
else
  echo "  FAIL DR-PLAN mentions only $patt DR patterns (expected >=2)"
  fail=$((fail+1))
fi

# Must mention RTO and RPO.
if grep -qi 'rto' "$DR"; then
  echo "  OK   DR-PLAN mentions RTO"
else
  echo "  FAIL DR-PLAN does not mention RTO"
  fail=$((fail+1))
fi

if grep -qi 'rpo' "$DR"; then
  echo "  OK   DR-PLAN mentions RPO"
else
  echo "  FAIL DR-PLAN does not mention RPO"
  fail=$((fail+1))
fi

# Must mention relative cost (factura, baseline, 1.x, 2.x).
if grep -qiE 'baseline|factura|1\.[0-9]x|2\.[0-9]x|relativ'  "$DR"; then
  echo "  OK   DR-PLAN discusses relative cost"
else
  echo "  FAIL DR-PLAN does not discuss relative cost"
  fail=$((fail+1))
fi

# Runbook: at least 7 numbered steps.
runbook_steps=0
for n in 1 2 3 4 5 6 7; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DR"; then
    runbook_steps=$((runbook_steps+1))
  fi
done
if [ "$runbook_steps" -ge 7 ]; then
  echo "  OK   DR-PLAN runbook has at least 7 numbered steps"
else
  echo "  FAIL DR-PLAN has only $runbook_steps numbered steps (expected >=7)"
  fail=$((fail+1))
fi

# Must mention a test cadence keyword.
if grep -qiE 'game day|tabletop|trimestral|semestral|anual|cadencia' "$DR"; then
  echo "  OK   DR-PLAN mentions test cadence (game day / tabletop / ...)"
else
  echo "  FAIL DR-PLAN does not mention test cadence"
  fail=$((fail+1))
fi

# ============================
# COST-EXPLORER-WALKTHROUGH.md
# ============================

# At least 10 numbered steps.
ce_steps=0
for n in 1 2 3 4 5 6 7 8 9 10; do
  if grep -Eq "^[[:space:]]*${n}\\." "$CE"; then
    ce_steps=$((ce_steps+1))
  fi
done
if [ "$ce_steps" -ge 10 ]; then
  echo "  OK   COST-EXPLORER walkthrough has at least 10 numbered steps"
else
  echo "  FAIL COST-EXPLORER walkthrough has only $ce_steps numbered steps (expected >=10)"
  fail=$((fail+1))
fi

# Must mention group by / filter / tag / savings plan.
for term in "group by|group-by|agrupa" "filter|filtro" "tag|etiqueta" "savings plan|reserved instance|\\bRI\\b"; do
  if grep -qiE "$term" "$CE"; then
    echo "  OK   COST-EXPLORER mentions: $term"
  else
    echo "  FAIL COST-EXPLORER missing: $term"
    fail=$((fail+1))
  fi
done

# Must mention Cost Explorer explicitly.
if grep -qi 'cost explorer' "$CE"; then
  echo "  OK   COST-EXPLORER mentions Cost Explorer"
else
  echo "  FAIL COST-EXPLORER does not mention Cost Explorer"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara los 3 documentos con solution/REFERENCE.md para autoevaluarte."
exit 0
