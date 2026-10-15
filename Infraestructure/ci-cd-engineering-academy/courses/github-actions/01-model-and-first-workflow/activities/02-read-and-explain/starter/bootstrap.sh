#!/usr/bin/env bash
# Bootstrap for gha-01-02-read-and-explain.
# Creates:
#   $BASE/workflow-under-review.yml  (the given workflow — DO NOT edit)
#   $BASE/ANSWERS.md                 (the form the student fills in)
set -euo pipefail

BASE="${1:-/tmp/gha-01-read-and-explain}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

rm -rf "$BASE"
mkdir -p "$BASE"

cp "$SCRIPT_DIR/workflow-under-review.yml" "$BASE/workflow-under-review.yml"

cat > "$BASE/ANSWERS.md" <<'EOF'
# ANSWERS — gha-01-02-read-and-explain

Rellena cada sección debajo del heading correspondiente.
No modifiques `workflow-under-review.yml`.

## Q1
<!-- Qué triggers tiene; cuántos runs se crean en push a main vs en PR a main. -->

## Q2
<!-- Jobs, orden, qué pasa si uno falla. -->

## Q3
<!-- El job publish NO tiene checkout: consecuencia y si es bug. -->

## Q4
<!-- Clasifica los 3 steps del job build como uses o run y qué hacen. -->

## Q5
<!-- Variables $GITHUB_* en el step Report: de dónde salen y cuándo. -->

## Q6
<!-- Re-run failed jobs: qué YAML usa. -->
EOF

echo "== Bootstrap OK =="
echo "Workflow (read-only): $BASE/workflow-under-review.yml"
echo "Form to fill:          $BASE/ANSWERS.md"
echo
echo "Next:"
echo "  1) Abre y lee $BASE/workflow-under-review.yml (NO lo edites)."
echo "  2) Edita $BASE/ANSWERS.md respondiendo las 6 preguntas."
echo "  3) bash .../tests/validate.sh $BASE"
