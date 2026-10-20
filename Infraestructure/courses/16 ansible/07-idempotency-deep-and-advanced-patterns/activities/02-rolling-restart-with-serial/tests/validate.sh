#!/usr/bin/env bash
# Validator for ans-07-02-rolling-restart-with-serial.
# Verifica estructura de inventory.ini y rolling.yml, luego ejecuta el
# rolling restart y comprueba el orden en el processed.log + flag global.
#
# Nota: deliberadamente NO habilitamos `set -o pipefail`. Varias comprobaciones
# usan `... | grep -q ...` que puede devolver SIGPIPE (exit 141) cuando grep
# encuentra la coincidencia pronto; pipefail las marcaria como fallo falso.

set -eu

BASE="${1:-/tmp/ans-07-02}"
INV="$BASE/inventory.ini"
PLAY="$BASE/rolling.yml"
PROCESSED=/tmp/ans-07-02.processed.log
DONE=/tmp/ans-07-02.done
fail=0

echo "== Validating ans-07-02 in $BASE =="

if [ ! -f "$INV" ]; then
  echo "FAIL: $INV no existe."
  exit 1
fi
if [ ! -f "$PLAY" ]; then
  echo "FAIL: $PLAY no existe."
  exit 1
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "FAIL: ansible-playbook no esta en PATH. Instala ansible-core."
  exit 1
fi

# inventory structure.
if grep -qE '^\[web\]' "$INV"; then
  echo "  OK   inventory tiene grupo [web]"
else
  echo "  FAIL inventory sin grupo [web]"; fail=$((fail+1))
fi
if grep -qE '^lb-primary' "$INV"; then
  echo "  OK   inventory tiene host lb-primary"
else
  echo "  FAIL inventory sin host lb-primary"; fail=$((fail+1))
fi

# YAML valido.
if ! python3 -c "import sys, yaml; yaml.safe_load(open('$PLAY'))" >/dev/null 2>&1; then
  echo "  FAIL rolling.yml no es YAML valido"; fail=$((fail+1))
else
  echo "  OK   rolling.yml es YAML valido"
fi

# Patrones requeridos.
for pattern_label in \
  "serial:[[:space:]]*1|serial 1" \
  "max_fail_percentage:[[:space:]]*0|max_fail_percentage 0" \
  "delegate_to:[[:space:]]*lb-primary|delegate_to lb-primary" \
  "run_once:[[:space:]]*true|run_once true" \
  "^[[:space:]]*block:|block" \
  "^[[:space:]]*rescue:|rescue" \
  "^[[:space:]]*always:|always"
do
  pattern="${pattern_label%|*}"
  label="${pattern_label##*|}"
  if grep -qE "$pattern" "$PLAY"; then
    echo "  OK   usa '$label'"
  else
    echo "  FAIL falta '$label'"; fail=$((fail+1))
  fi
done

# delegate_to debe aparecer al menos 2 veces (drain + undrain).
dcount=$(grep -cE 'delegate_to:[[:space:]]*lb-primary' "$PLAY" || true)
if [ "$dcount" -ge 2 ]; then
  echo "  OK   delegate_to: lb-primary aparece $dcount veces (>=2)"
else
  echo "  FAIL delegate_to: lb-primary aparece solo $dcount veces (esperado >=2)"
  fail=$((fail+1))
fi

echo
echo "-- Limpiando logs previos y ejecutando rolling --"
rm -f "$PROCESSED" "$DONE" /tmp/ans-07-02.failed.log
cd "$BASE"
if ! ansible-playbook -i inventory.ini rolling.yml >/tmp/ans-07-02.run.log 2>&1; then
  echo "  FAIL ejecucion del rolling retorno error. Log en /tmp/ans-07-02.run.log"
  tail -40 /tmp/ans-07-02.run.log || true
  fail=$((fail+1))
else
  echo "  OK   rolling ejecuto sin error"
fi

# Processed log debe tener exactamente los 3 hosts en orden.
if [ ! -f "$PROCESSED" ]; then
  echo "  FAIL $PROCESSED no fue creado"; fail=$((fail+1))
else
  expected=$'web-a\nweb-b\nweb-c'
  actual=$(cat "$PROCESSED")
  if [ "$actual" = "$expected" ]; then
    echo "  OK   processed.log tiene los 3 hosts en orden"
  else
    echo "  FAIL processed.log no coincide. Esperado:"
    printf '%s\n' "$expected"
    echo "        Obtenido:"
    printf '%s\n' "$actual"
    fail=$((fail+1))
  fi
fi

if [ -f "$DONE" ]; then
  echo "  OK   flag global $DONE existe (run_once + delegate_to funciono)"
else
  echo "  FAIL flag global $DONE no existe"; fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s)."
  exit 1
fi
echo "RESULT: 0 issue(s). Rolling restart correcto."
exit 0
