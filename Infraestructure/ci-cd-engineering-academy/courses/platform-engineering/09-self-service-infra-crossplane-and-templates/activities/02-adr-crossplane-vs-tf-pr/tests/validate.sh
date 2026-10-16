#!/usr/bin/env bash
# Structural validation for plat-09-02-adr-crossplane-vs-tf-pr.
# Checks that ADR.md exists and has the required structure.
#
# Note: deliberately NO `set -o pipefail` because several checks use
# `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# exits on first match. pipefail would spuriously report those as failures.
#
# Does NOT grade semantic correctness — compare with solution/REFERENCE.md.
set -eu

BASE="${1:-/tmp/plat-09-02-adr}"
DOC="$BASE/ADR.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Debes crearlo."
  exit 1
fi

# Must have 3 "Contexto N" headings
for n in 1 2 3; do
  if grep -qiE "^#+ *Contexto *$n" "$DOC"; then
    echo "  OK   ADR.md tiene heading 'Contexto $n'"
  else
    echo "  FAIL ADR.md no tiene heading 'Contexto $n'"
    fail=$((fail+1))
  fi
done

# Each context should mention a decision keyword
dec_count=$(grep -ciE 'decisi[oó]n *:' "$DOC" || true)
if [ "${dec_count:-0}" -ge 3 ]; then
  echo "  OK   ADR.md tiene al menos 3 'Decision:' ($dec_count encontrados)"
else
  echo "  FAIL ADR.md tiene $dec_count 'Decision:' (esperado >=3)"
  fail=$((fail+1))
fi

# Must mention Crossplane and Terraform
if grep -qi 'crossplane' "$DOC"; then
  echo "  OK   menciona Crossplane"
else
  echo "  FAIL no menciona Crossplane"
  fail=$((fail+1))
fi
if grep -qi 'terraform' "$DOC"; then
  echo "  OK   menciona Terraform"
else
  echo "  FAIL no menciona Terraform"
  fail=$((fail+1))
fi

# Must have the key vocabulary of the module
vocab=0
for term in "xrd" "composition" "claim" "atlantis" "gitops" "kyverno"; do
  if grep -qi "$term" "$DOC"; then
    vocab=$((vocab+1))
  fi
done
if [ "$vocab" -ge 4 ]; then
  echo "  OK   usa vocabulario tecnico suficiente ($vocab/6 terminos)"
else
  echo "  FAIL vocabulario tecnico pobre ($vocab/6; esperado >=4)"
  fail=$((fail+1))
fi

# Comparativa en 7 dimensiones: >= 10 pipe-lines
pipes=$(grep -cE '^\|' "$DOC" || true)
if [ "${pipes:-0}" -ge 9 ]; then
  echo "  OK   tabla comparativa con $pipes pipe-lines (>=9)"
else
  echo "  FAIL tabla comparativa pobre: $pipes pipe-lines (esperado >=9)"
  fail=$((fail+1))
fi

# Must mention at least 4 of the 7 dimensions by keyword
dims=0
for d in "stack" "curva" "debug" "gitops" "policy" "overhead" "rollback"; do
  if grep -qi "$d" "$DOC"; then
    dims=$((dims+1))
  fi
done
if [ "$dims" -ge 4 ]; then
  echo "  OK   nombra $dims dimensiones comparativas (>=4)"
else
  echo "  FAIL solo $dims dimensiones comparativas nombradas (esperado >=4)"
  fail=$((fail+1))
fi

# 5 numbered criterion questions (1. .. 5.)
qfound=0
for n in 1 2 3 4 5; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    qfound=$((qfound+1))
  fi
done
if [ "$qfound" -ge 5 ]; then
  echo "  OK   ADR.md tiene al menos 5 preguntas-criterio numeradas"
else
  echo "  FAIL ADR.md tiene $qfound preguntas numeradas (esperado >=5)"
  fail=$((fail+1))
fi

# Riesgo + mitigacion al menos 2 veces
risk=$(grep -ciE 'riesgo|mitigaci[oó]n' "$DOC" || true)
if [ "${risk:-0}" -ge 3 ]; then
  echo "  OK   menciona riesgo/mitigacion al menos 3 veces ($risk)"
else
  echo "  FAIL riesgo/mitigacion mencionado $risk veces (esperado >=3)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Correctitud semantica es TU responsabilidad — compara con solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara ADR.md con solution/REFERENCE.md para autoevaluarte."
exit 0
