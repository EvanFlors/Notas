#!/usr/bin/env bash
# Structural + execution validation for plat-10-01-scorecard-for-capstone.
#
# Checks:
#   - scorecard.yaml exists, has levels (bronze/silver/gold), has 5-8 checks.
#   - NOTES.md exists with sections A, B, C and names at least one antipattern.
#   - If python3 + pyyaml are available, runs scripts/evaluate.py and verifies
#     results.json + REPORT.md are produced. Otherwise reports SKIP for the
#     execution part (structural part still runs).
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-10-scorecard}"
SCORECARD="$BASE/scorecard.yaml"
NOTES="$BASE/NOTES.md"
CATALOG="$BASE/catalog"
SCRIPT="$BASE/scripts/evaluate.py"
fail=0
skipped=0

echo "== Validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Copy starter/ into it first."
  exit 1
fi

# --- scorecard.yaml checks -------------------------------------------------
if [ ! -f "$SCORECARD" ]; then
  echo "  FAIL $SCORECARD does not exist. Copy scorecard.yaml.template and edit."
  fail=$((fail+1))
else
  echo "  OK   $SCORECARD exists"

  for lvl in bronze silver gold; do
    if grep -qE "^[[:space:]]*-[[:space:]]+${lvl}[[:space:]]*$" "$SCORECARD"; then
      echo "  OK   scorecard.yaml declares level '$lvl'"
    else
      echo "  FAIL scorecard.yaml missing level '$lvl'"
      fail=$((fail+1))
    fi
  done

  # Count checks by their 'id:' lines (checks[].id). A level block has no 'id'.
  checks_count=$(grep -cE "^[[:space:]]+-[[:space:]]+id:[[:space:]]+" "$SCORECARD" || true)
  if [ "$checks_count" -ge 5 ] && [ "$checks_count" -le 8 ]; then
    echo "  OK   scorecard.yaml has $checks_count checks (expected 5-8)"
  else
    echo "  FAIL scorecard.yaml has $checks_count checks (expected 5-8)"
    fail=$((fail+1))
  fi

  for key in weight field operator; do
    if grep -qE "^[[:space:]]+${key}:" "$SCORECARD"; then
      echo "  OK   scorecard.yaml uses key '$key'"
    else
      echo "  FAIL scorecard.yaml does not use key '$key'"
      fail=$((fail+1))
    fi
  done
fi

# --- NOTES.md checks -------------------------------------------------------
if [ ! -f "$NOTES" ]; then
  echo "  FAIL $NOTES does not exist. Write it with sections A, B, C."
  fail=$((fail+1))
else
  echo "  OK   $NOTES exists"
  if grep -qiE '^#+ *(Secci[óo]n +A|Decisiones)' "$NOTES"; then
    echo "  OK   NOTES.md has Section A"
  else
    echo "  FAIL NOTES.md missing Section A (Decisiones de diseño)"
    fail=$((fail+1))
  fi
  if grep -qiE '^#+ *(Secci[óo]n +B|Lectura)' "$NOTES"; then
    echo "  OK   NOTES.md has Section B"
  else
    echo "  FAIL NOTES.md missing Section B (Lectura del reporte)"
    fail=$((fail+1))
  fi
  if grep -qiE '^#+ *(Secci[óo]n +C|Adopci[óo]n)' "$NOTES"; then
    echo "  OK   NOTES.md has Section C"
  else
    echo "  FAIL NOTES.md missing Section C (Adopción y antipatrones)"
    fail=$((fail+1))
  fi
  # Must name at least one antipattern token.
  if grep -qiE 'antipatron|antipatrón|gaming|ponderad|ranking|opaco' "$NOTES"; then
    echo "  OK   NOTES.md names at least one antipattern concept"
  else
    echo "  FAIL NOTES.md does not name any antipattern concept"
    fail=$((fail+1))
  fi
  # Must mention bronze/silver/gold at least once.
  if grep -qiE 'bronze|silver|gold' "$NOTES"; then
    echo "  OK   NOTES.md references the maturity levels"
  else
    echo "  FAIL NOTES.md does not reference bronze/silver/gold"
    fail=$((fail+1))
  fi
fi

# --- Optional: run evaluate.py if tools available --------------------------
have_python=0
have_yaml=0
if command -v python3 >/dev/null 2>&1; then
  have_python=1
  if python3 -c "import yaml" >/dev/null 2>&1; then
    have_yaml=1
  fi
fi

if [ -f "$SCORECARD" ] && [ -d "$CATALOG" ] && [ -f "$SCRIPT" ] \
   && [ "$have_python" -eq 1 ] && [ "$have_yaml" -eq 1 ]; then
  echo "  --   running evaluator..."
  if python3 "$SCRIPT" --scorecard "$SCORECARD" --catalog "$CATALOG" --out "$BASE" >/dev/null 2>&1; then
    echo "  OK   evaluate.py ran without errors"
    if [ -f "$BASE/results.json" ]; then
      echo "  OK   results.json produced"
    else
      echo "  FAIL results.json not produced"
      fail=$((fail+1))
    fi
    if [ -f "$BASE/REPORT.md" ]; then
      echo "  OK   REPORT.md produced"
    else
      echo "  FAIL REPORT.md not produced"
      fail=$((fail+1))
    fi
  else
    echo "  FAIL evaluate.py exited with error"
    fail=$((fail+1))
  fi
else
  if [ "$have_python" -ne 1 ]; then
    echo "  SKIP python3 not available — evaluator not run (structural checks still apply)"
  elif [ "$have_yaml" -ne 1 ]; then
    echo "  SKIP python3 pyyaml not available — evaluator not run (structural checks still apply)"
  else
    echo "  SKIP catalog/ or scripts/evaluate.py missing — evaluator not run"
  fi
  skipped=$((skipped+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed, $skipped skipped."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida ($skipped skipped). Compara scorecard.yaml + NOTES.md con solution/REFERENCE.md."
exit 0
