#!/usr/bin/env bash
# Structural validation for sec-12-01-trigger-and-detect-shell-in-pod.
# Checks that DETECTION.md exists under BASE and contains the required
# four sections, a 5-step runbook, and the key vocabulary.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Many checks pipe
# into grep which can emit SIGPIPE (exit 141) when grep finds a match early;
# pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness. Compare manually with
# solution/REFERENCE.md.
set -eu

BASE="${1:-/tmp/sec-12-detect}"
DOC="$BASE/DETECTION.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC no existe. Debes producirlo."
  exit 1
fi

# Required sections A, B, C, D.
for label in \
  'A|Evento' \
  'B|An[aá]lisis' \
  'C|Runbook' \
  'D|Decisi[oó]n|detect.*enforce'
do
  if grep -qiE "^#+ *(Secci[oó]n +)?(${label})" "$DOC"; then
    echo "  OK   DETECTION.md tiene Seccion coincidente con /${label}/"
  else
    echo "  FAIL DETECTION.md no tiene Seccion coincidente con /${label}/"
    fail=$((fail+1))
  fi
done

# Must mention Falco and Tetragon.
if grep -qi 'falco' "$DOC"; then
  echo "  OK   menciona Falco"
else
  echo "  FAIL no menciona Falco"
  fail=$((fail+1))
fi

if grep -qi 'tetragon' "$DOC"; then
  echo "  OK   menciona Tetragon"
else
  echo "  FAIL no menciona Tetragon"
  fail=$((fail+1))
fi

# Must mention at least one canonical rule name.
if grep -qiE 'Terminal shell in container|Read sensitive file' "$DOC"; then
  echo "  OK   nombra al menos una regla canonica"
else
  echo "  FAIL no nombra regla canonica (Terminal shell in container / Read sensitive file)"
  fail=$((fail+1))
fi

# Must extract Pod / image / user / cmdline cues.
cues=0
for p in 'pod' 'imagen|image' 'usuario|user' 'cmdline'; do
  if grep -qiE "$p" "$DOC"; then
    cues=$((cues+1))
  fi
done
if [ "$cues" -ge 4 ]; then
  echo "  OK   extrae pod/imagen/usuario/cmdline ($cues/4)"
else
  echo "  FAIL extrae solo $cues/4 campos (pod/imagen/usuario/cmdline)"
  fail=$((fail+1))
fi

# Runbook: at least 5 numbered steps (1. .. 5.).
steps=0
for n in 1 2 3 4 5; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    steps=$((steps+1))
  fi
done
if [ "$steps" -ge 5 ]; then
  echo "  OK   runbook tiene al menos 5 pasos numerados"
else
  echo "  FAIL runbook tiene $steps pasos numerados (esperado >=5)"
  fail=$((fail+1))
fi

# Decision vocabulary: detect/enforce/depende.
if grep -qiE 'detect|enforce|depende' "$DOC"; then
  echo "  OK   usa vocabulario de decision (detect/enforce/depende)"
else
  echo "  FAIL no usa vocabulario de decision (detect/enforce/depende)"
  fail=$((fail+1))
fi

# At least one source event artifact present under BASE (raw-events.log or raw-events.json).
if [ -f "$BASE/raw-events.log" ] || [ -f "$BASE/raw-events.json" ]; then
  echo "  OK   artefacto de eventos presente (raw-events.log o raw-events.json)"
else
  echo "  WARN sin raw-events.log|json en $BASE (ok si solo documentaste walkthrough)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) estructural(es) fallaron."
  echo "        (La correccion semantica es tu responsabilidad — compara con solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara DETECTION.md con solution/REFERENCE.md."
exit 0
