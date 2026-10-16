#!/usr/bin/env bash
# Structural validation for sec-12-02-rule-authoring-exercise.
# Checks:
#   - custom-rules.yaml exists under BASE and parses as YAML (if python3 available).
#   - custom-rules.yaml contains at least one 'rule:' entry with the required
#     keys (desc, condition, output, priority).
#   - RULES.md exists with 4 sections (A, B, C, D) and the expected cues.
#   - FP and FN sections each have at least 2 numbered items.
#   - A valid priority token is used.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Many checks pipe into
# grep which can emit SIGPIPE (exit 141) when the match is found early;
# pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare with solution/REFERENCE.md.
set -eu

BASE="${1:-/tmp/sec-12-rule}"
YAML="$BASE/custom-rules.yaml"
DOC="$BASE/RULES.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$YAML" ]; then
  echo "FAIL: $YAML no existe."
  exit 1
fi
if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC no existe."
  exit 1
fi

# YAML parse check (best effort).
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import yaml,sys; yaml.safe_load(open('$YAML'))" >/dev/null 2>&1; then
    echo "  OK   custom-rules.yaml es YAML valido"
  else
    echo "  FAIL custom-rules.yaml no es YAML valido"
    fail=$((fail+1))
  fi
else
  echo "  WARN python3 no disponible; skip YAML parse check"
fi

# At least one 'rule:' entry.
rules_count=$(grep -cE '^[[:space:]]*-[[:space:]]+rule:' "$YAML" || true)
if [ "$rules_count" -ge 1 ]; then
  echo "  OK   custom-rules.yaml tiene $rules_count regla(s)"
else
  echo "  FAIL custom-rules.yaml no tiene ninguna entrada 'rule:'"
  fail=$((fail+1))
fi

# Required keys inside the rules file (presence anywhere, best-effort structural).
for key in desc condition output priority; do
  if grep -qE "^[[:space:]]+${key}:" "$YAML"; then
    echo "  OK   custom-rules.yaml menciona clave '$key'"
  else
    echo "  FAIL custom-rules.yaml no menciona clave '$key'"
    fail=$((fail+1))
  fi
done

# Priority must be a valid token somewhere.
if grep -qE 'priority:[[:space:]]*(EMERGENCY|ALERT|CRITICAL|ERROR|WARNING|NOTICE|INFO|DEBUG)' "$YAML"; then
  echo "  OK   priority es un token valido"
else
  echo "  FAIL priority no es un token valido Falco"
  fail=$((fail+1))
fi

# Rule must mention /var/log and world-writable (777 / 0777 / 0666).
if grep -q '/var/log' "$YAML"; then
  echo "  OK   la regla menciona /var/log"
else
  echo "  FAIL la regla no menciona /var/log"
  fail=$((fail+1))
fi

if grep -qE '0?777|0?666|S_IWOTH' "$YAML"; then
  echo "  OK   la regla menciona permisos world-writable (777/666/S_IWOTH)"
else
  echo "  FAIL la regla no menciona permisos world-writable"
  fail=$((fail+1))
fi

# RULES.md: 4 sections.
for label in \
  'A|Regla propuesta' \
  'B|Falsos positivos' \
  'C|Falsos negativos' \
  'D|Decisi[oó]n|detect.*enforce'
do
  if grep -qiE "^#+ *(Secci[oó]n +)?(${label})" "$DOC"; then
    echo "  OK   RULES.md tiene Seccion coincidente con /${label}/"
  else
    echo "  FAIL RULES.md no tiene Seccion coincidente con /${label}/"
    fail=$((fail+1))
  fi
done

# FP: at least 2 numbered items under Section B.
fp_count=0
for n in 1 2; do
  if grep -Eq "^[[:space:]]*${n}\\." "$DOC"; then
    fp_count=$((fp_count+1))
  fi
done
if [ "$fp_count" -ge 2 ]; then
  echo "  OK   RULES.md tiene al menos 2 items numerados (FP o FN)"
else
  echo "  FAIL RULES.md tiene menos de 2 items numerados"
  fail=$((fail+1))
fi

# Must mention Falco and Tetragon in RULES.md.
if grep -qi 'falco' "$DOC"; then
  echo "  OK   RULES.md menciona Falco"
else
  echo "  FAIL RULES.md no menciona Falco"
  fail=$((fail+1))
fi
if grep -qi 'tetragon' "$DOC"; then
  echo "  OK   RULES.md menciona Tetragon"
else
  echo "  FAIL RULES.md no menciona Tetragon"
  fail=$((fail+1))
fi

# Decision vocabulary.
if grep -qiE 'detect|enforce|depende' "$DOC"; then
  echo "  OK   RULES.md usa vocabulario de decision"
else
  echo "  FAIL RULES.md no usa vocabulario de decision (detect/enforce/depende)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) estructural(es) fallaron."
  echo "        (La correccion semantica es tu responsabilidad — compara con solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md y solution/custom-rules.yaml."
exit 0
