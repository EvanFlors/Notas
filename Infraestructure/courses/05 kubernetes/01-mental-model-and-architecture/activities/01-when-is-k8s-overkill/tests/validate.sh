#!/usr/bin/env bash
# Structural validation for k8s-01-01-when-is-k8s-overkill.
# Checks that ADR.md exists and contains the required sections, keywords,
# alternatives and 7 numbered answers.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/ADR-reference.md.

BASE="${1:-/tmp/k8s-01-overkill}"
DOC="$BASE/ADR.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Four required ADR sections.
required_sections=(
  "Contexto"
  "Decisi"
  "Consecuencias"
  "Alternativas"
)
for s in "${required_sections[@]}"; do
  if grep -qi "$s" "$DOC"; then
    echo "  OK   ADR.md mentions section: '$s'"
  else
    echo "  FAIL ADR.md missing section: '$s'"
    fail=$((fail+1))
  fi
done

# Must mention Kubernetes / K8s.
if grep -qiE 'kubernetes|k8s' "$DOC"; then
  echo "  OK   mentions Kubernetes / K8s"
else
  echo "  FAIL does not mention Kubernetes / K8s"
  fail=$((fail+1))
fi

# Must mention the current baseline (Docker Compose / VPS).
if grep -qiE 'compose|vps' "$DOC"; then
  echo "  OK   mentions current baseline (compose/VPS)"
else
  echo "  FAIL does not mention current baseline (compose/VPS)"
  fail=$((fail+1))
fi

# Must mention 'managed' or a managed offering.
if grep -qiE 'managed|eks|gke|aks' "$DOC"; then
  echo "  OK   mentions managed offering (managed/EKS/GKE/AKS)"
else
  echo "  FAIL does not mention managed offering"
  fail=$((fail+1))
fi

# Must mention at least one named alternative beyond K8s itself.
alts_found=0
for alt in "nomad" "ecs" "fargate" "cloud run" "app runner" "serverless" "lambda" "fly.io"; do
  if grep -qi "$alt" "$DOC"; then
    alts_found=$((alts_found+1))
  fi
done
if [ "$alts_found" -ge 2 ]; then
  echo "  OK   ADR.md names at least 2 alternatives ($alts_found found)"
else
  echo "  FAIL ADR.md names only $alts_found alternatives (expected >=2)"
  fail=$((fail+1))
fi

# Must mention 'trigger' or 'disparador' (criteria to revisit the decision).
if grep -qiE 'disparador|trigger' "$DOC"; then
  echo "  OK   mentions trigger/disparador for revisiting the decision"
else
  echo "  FAIL does not mention trigger/disparador"
  fail=$((fail+1))
fi

# Must mention cost / costo.
if grep -qiE 'costo|coste|cost' "$DOC"; then
  echo "  OK   mentions cost / costo"
else
  echo "  FAIL does not mention cost / costo"
  fail=$((fail+1))
fi

# Must mention team / equipo size.
if grep -qiE 'equipo|team' "$DOC"; then
  echo "  OK   mentions team / equipo"
else
  echo "  FAIL does not mention team / equipo"
  fail=$((fail+1))
fi

# At least 5 numbered items somewhere (triggers list OR questions).
# We count numbered lines of the form "N." at start of line, for N 1..9.
numbered_lines=$(grep -cE '^[[:space:]]*[1-9]\.' "$DOC")
if [ "$numbered_lines" -ge 5 ]; then
  echo "  OK   ADR.md contains $numbered_lines numbered items (triggers + answers)"
else
  echo "  FAIL ADR.md contains only $numbered_lines numbered items (expected >=5 for triggers)"
  fail=$((fail+1))
fi

# 7 numbered answers (preguntas obligatorias) — look for 1. through 7.
answers_found=0
for n in 1 2 3 4 5 6 7; do
  if grep -Eq "^(##? )?${n}\\." "$DOC"; then
    answers_found=$((answers_found+1))
  fi
done
if [ "$answers_found" -ge 7 ]; then
  echo "  OK   ADR.md answers at least 7 numbered questions"
else
  echo "  FAIL ADR.md has $answers_found numbered answers (expected >=7)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/ADR-reference.md.)"
  exit 1
fi
echo "OK: estructura válida. Compara ADR.md con solution/ADR-reference.md para autoevaluarte."
exit 0
