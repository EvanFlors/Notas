#!/usr/bin/env bash
# Structural validation for sec-03-02-severity-policy-draft.
# Checks that SEVERITY_POLICY.md exists and contains the required sections,
# the priority taxonomy, the mapping matrix, suppression vs exception
# differentiation, and the process + metrics section.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -c ...` or `... | grep -q ...` which can produce SIGPIPE
# (exit 141) when grep finds a match early. pipefail would spuriously mark
# those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/sec-03-policy}"
DOC="$BASE/SEVERITY_POLICY.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Section A — Taxonomia / Prioridades.
if grep -qiE '^#+ *(Secci[óo]n +A|Taxonom[ií]a|Prioridades)' "$DOC"; then
  echo "  OK   SEVERITY_POLICY.md has Section A (Taxonomia/Prioridades)"
else
  echo "  FAIL SEVERITY_POLICY.md missing Section A / Taxonomia heading"
  fail=$((fail+1))
fi

# Section B — Matriz / Asignacion.
if grep -qiE '^#+ *(Secci[óo]n +B|Matriz|Asignaci[óo]n|Mapping)' "$DOC"; then
  echo "  OK   SEVERITY_POLICY.md has Section B (Matriz)"
else
  echo "  FAIL SEVERITY_POLICY.md missing Section B / Matriz heading"
  fail=$((fail+1))
fi

# Section C — Suppressions vs Exceptions.
if grep -qiE '^#+ *(Secci[óo]n +C|Suppression|Exception|Excepci[óo])' "$DOC"; then
  echo "  OK   SEVERITY_POLICY.md has Section C (Suppressions/Exceptions)"
else
  echo "  FAIL SEVERITY_POLICY.md missing Section C / Suppressions heading"
  fail=$((fail+1))
fi

# Section D — Proceso / Metricas.
if grep -qiE '^#+ *(Secci[óo]n +D|Proceso|M[eé]tricas|Metrics|Process)' "$DOC"; then
  echo "  OK   SEVERITY_POLICY.md has Section D (Proceso/Metricas)"
else
  echo "  FAIL SEVERITY_POLICY.md missing Section D / Proceso heading"
  fail=$((fail+1))
fi

# Priorities P0..P3 must appear (at least 4 labels).
priorities=0
for p in "P0" "P1" "P2" "P3"; do
  if grep -qE "\\b${p}\\b" "$DOC"; then
    priorities=$((priorities+1))
  fi
done
if [ "$priorities" -ge 4 ]; then
  echo "  OK   SEVERITY_POLICY.md defines at least 4 priorities ($priorities found)"
else
  echo "  FAIL SEVERITY_POLICY.md defines only $priorities priorities (expected >=4: P0..P3)"
  fail=$((fail+1))
fi

# Must mention CVSS, EPSS, KEV each at least once.
for term in "CVSS" "EPSS" "KEV"; do
  if grep -q "$term" "$DOC"; then
    echo "  OK   mentions $term"
  else
    echo "  FAIL does not mention $term"
    fail=$((fail+1))
  fi
done

# Must mention SLA at least once.
if grep -qiE 'sla|remediaci|remediation' "$DOC"; then
  echo "  OK   mentions SLA / remediacion"
else
  echo "  FAIL does not mention SLA / remediacion"
  fail=$((fail+1))
fi

# Matrix section: at least 5 table rows (header + separator + 5 = 7 pipe-lines).
rows=$(grep -cE '^\|' "$DOC" || true)
if [ "$rows" -ge 7 ]; then
  echo "  OK   SEVERITY_POLICY.md has at least 5 matrix rows ($rows pipe-lines found)"
else
  echo "  FAIL SEVERITY_POLICY.md matrix has only $rows pipe-lines (expected >=7)"
  fail=$((fail+1))
fi

# Must mention suppression and exception explicitly.
if grep -qiE 'suppress' "$DOC"; then
  echo "  OK   mentions suppression"
else
  echo "  FAIL does not mention suppression"
  fail=$((fail+1))
fi
if grep -qiE 'excepti|excepci' "$DOC"; then
  echo "  OK   mentions exception / excepcion"
else
  echo "  FAIL does not mention exception / excepcion"
  fail=$((fail+1))
fi

# Must mention expires / expiracion (expiration obligation).
if grep -qiE 'expires|expiraci|expiration' "$DOC"; then
  echo "  OK   mentions expiration / expires_at"
else
  echo "  FAIL does not mention expiration / expires_at"
  fail=$((fail+1))
fi

# Must mention owner and approver.
if grep -qiE 'owner' "$DOC"; then
  echo "  OK   mentions owner"
else
  echo "  FAIL does not mention owner"
  fail=$((fail+1))
fi
if grep -qiE 'approver|aprobador|approval|aprobaci' "$DOC"; then
  echo "  OK   mentions approver / aprobacion"
else
  echo "  FAIL does not mention approver / aprobacion"
  fail=$((fail+1))
fi

# Section D: metrics — must have at least 3 numbered items.
metrics_found=0
for n in 1 2 3; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    metrics_found=$((metrics_found+1))
  fi
done
if [ "$metrics_found" -ge 3 ]; then
  echo "  OK   SEVERITY_POLICY.md has at least 3 numbered items (metrics)"
else
  echo "  FAIL SEVERITY_POLICY.md has $metrics_found numbered items (expected >=3)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara SEVERITY_POLICY.md con solution/REFERENCE.md para autoevaluarte."
exit 0
