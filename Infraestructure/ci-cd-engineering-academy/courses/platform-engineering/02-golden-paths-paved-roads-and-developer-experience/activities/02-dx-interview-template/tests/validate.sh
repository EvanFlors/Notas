#!/usr/bin/env bash
# Structural validation for plat-02-02-dx-interview-template.
# Checks that TEMPLATE.md exists, has the 6 required sections,
# at least 6 open numbered questions, sampling / cadence / responsible
# markers, and triangulation with survey + telemetry.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/TEMPLATE.md.

set -eu

BASE="${1:-/tmp/plat-02-dx-interview}"
DOC="$BASE/TEMPLATE.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Required 6 sections.
required_sections=(
  "Metadatos|Metadata"
  "Rapport"
  "Contexto|Context"
  "Preguntas|Questions"
  "Cierre|Closing"
  "M[ée]todo|Method"
)

idx=1
for pattern in "${required_sections[@]}"; do
  if grep -qiE "^#+ *${idx}\. *(${pattern})" "$DOC"; then
    echo "  OK   section ${idx} present"
  else
    echo "  FAIL section ${idx} ('${pattern}') missing or not numbered"
    fail=$((fail+1))
  fi
  idx=$((idx+1))
done

# At least 6 numbered questions anywhere between section 4 and 5.
questions_block=$(awk '/^#+ *4\./,/^#+ *5\./' "$DOC")
qcount=$(printf '%s\n' "$questions_block" | grep -cE '^[[:space:]]*[0-9]+\.' || true)
if [ "$qcount" -ge 6 ]; then
  echo "  OK   at least 6 numbered questions in section 4 ($qcount found)"
else
  echo "  FAIL only $qcount numbered questions in section 4 (expected >=6)"
  fail=$((fail+1))
fi

# Prohibit leading question patterns.
if printf '%s\n' "$questions_block" | grep -qiE '"\s*¿?\s*te gusta'; then
  echo "  WARN leading question detected ('te gusta') — review manually"
fi

# Must mention sampling / muestreo.
if grep -qiE 'muestreo|sampling|estratific' "$DOC"; then
  echo "  OK   mentions sampling / muestreo"
else
  echo "  FAIL does not mention sampling / muestreo"
  fail=$((fail+1))
fi

# Must mention cadence (trimestral/semestral/mensual/cadencia).
if grep -qiE 'cadencia|trimestral|semestral|mensual|quarterly|monthly'  "$DOC"; then
  echo "  OK   mentions cadence"
else
  echo "  FAIL does not mention cadence"
  fail=$((fail+1))
fi

# Must mention a DRI / responsable concrete.
if grep -qiE 'dri|responsable|owner'  "$DOC"; then
  echo "  OK   mentions DRI / responsable / owner"
else
  echo "  FAIL does not mention DRI / responsable"
  fail=$((fail+1))
fi

# Must mention triangulation with survey + telemetry.
if grep -qi 'survey' "$DOC" || grep -qiE 'encuesta' "$DOC"; then
  echo "  OK   mentions survey/encuesta"
else
  echo "  FAIL does not mention survey/encuesta"
  fail=$((fail+1))
fi
if grep -qiE 'telemetr[íi]a|telemetry' "$DOC"; then
  echo "  OK   mentions telemetry/telemetria"
else
  echo "  FAIL does not mention telemetry/telemetria"
  fail=$((fail+1))
fi

# Must mention consent / consentimiento in metadata.
if grep -qiE 'consentimiento|consent' "$DOC"; then
  echo "  OK   mentions consent / consentimiento"
else
  echo "  FAIL does not mention consent / consentimiento"
  fail=$((fail+1))
fi

# Must mention long tail / off-road / salirte-del-path to prove coverage.
if grep -qiE 'long[- ]?tail|off[- ]?road|sal(irte|ir) del (golden )?path|fuera del path' "$DOC"; then
  echo "  OK   addresses long tail / off-road"
else
  echo "  FAIL does not address long tail / off-road"
  fail=$((fail+1))
fi

# Must mention Platform NPS or DX.
if grep -qiE 'nps|dx\b|developer experience' "$DOC"; then
  echo "  OK   mentions NPS / DX"
else
  echo "  FAIL does not mention NPS / DX"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/TEMPLATE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara TEMPLATE.md con solution/TEMPLATE.md para autoevaluarte."
exit 0
