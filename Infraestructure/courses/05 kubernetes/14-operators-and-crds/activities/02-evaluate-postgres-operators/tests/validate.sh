#!/usr/bin/env bash
# Structural validator for the Postgres operators evaluation.
# The content quality is assessed manually; this script only verifies that
# the required sections exist and no TODO markers remain.
#
# Note: NO `set -o pipefail` on purpose — several checks use `grep -q` on piped
# input which can SIGPIPE the upstream.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
EVAL_FILE="$(cd "$HERE/.." && pwd)/starter/EVALUATION.md"

pass=0
fail=0
report=""
mark_ok()   { pass=$((pass+1)); report+="  OK   — $1\n"; }
mark_fail() { fail=$((fail+1)); report+="  FAIL — $1\n"; }

if [ ! -f "$EVAL_FILE" ]; then
  echo "FAIL: $EVAL_FILE missing."
  exit 1
fi

# Required section headers.
required_sections=(
  "## 1. Tabla comparativa"
  "## 2. Madurez del proyecto"
  "## 3. Blast radius"
  "## 4. Backup y restore"
  "## 5. Upgrade story"
  "## 6. Licencia y comunidad"
  "## 7. Red flags detectadas"
  "## 8. Recomendaciones por contexto"
  "## 9. Limitaciones de esta evaluación"
)

for section in "${required_sections[@]}"; do
  if grep -qF "$section" "$EVAL_FILE"; then
    mark_ok "section present: $section"
  else
    mark_fail "section missing: $section"
  fi
done

# TODO (student) markers must be gone.
todo_count="$(grep -c 'TODO (student)' "$EVAL_FILE" || true)"
if [ "$todo_count" -eq 0 ]; then
  mark_ok "no 'TODO (student)' markers left"
else
  mark_fail "$todo_count 'TODO (student)' markers still in EVALUATION.md"
fi

# At least 2 context recommendations with content under 8.1 and 8.2.
# Heuristic: there must be lines under those headers with real text (not just the TODO comment).
rec_8_1_lines="$(awk '/^### 8\.1/{flag=1; next} /^### /{flag=0} flag' "$EVAL_FILE" | grep -v '^[[:space:]]*$' | grep -vc 'TODO' || true)"
rec_8_2_lines="$(awk '/^### 8\.2/{flag=1; next} /^### /{flag=0} flag' "$EVAL_FILE" | grep -v '^[[:space:]]*$' | grep -vc 'TODO' || true)"
if [ "${rec_8_1_lines:-0}" -ge 1 ]; then
  mark_ok "recommendation 8.1 has content"
else
  mark_fail "recommendation 8.1 appears empty"
fi
if [ "${rec_8_2_lines:-0}" -ge 1 ]; then
  mark_ok "recommendation 8.2 has content"
else
  mark_fail "recommendation 8.2 appears empty"
fi

# Comparative table should have at least 10 data rows (lines starting with '| ' and containing '|').
table_rows="$(awk '/^\| / && !/^\| ?---/ && !/^\| Dimensión/{c++} END{print c+0}' "$EVAL_FILE")"
if [ "$table_rows" -ge 10 ]; then
  mark_ok "comparative table has $table_rows data rows (>=10)"
else
  mark_fail "comparative table has only $table_rows data rows (<10)"
fi

echo
printf "%b" "$report"
echo
total=$((pass+fail))
if [ "$fail" -eq 0 ]; then
  echo "RESULT: OK  structural checks: $pass/$total"
  echo "(Content quality is reviewed manually against the module rubric.)"
  exit 0
else
  echo "RESULT: FAIL  structural checks: $pass/$total"
  exit 1
fi
