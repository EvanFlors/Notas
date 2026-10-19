#!/usr/bin/env bash
# Validator for ans-07-01-make-playbook-idempotent.
# Comprueba estructura del site.yml y que la segunda corrida reporta changed=0.
#
# Nota: deliberadamente NO habilitamos `set -o pipefail`. Varios checks usan
# `... | grep -q ...` que puede producir SIGPIPE (exit 141) cuando grep encuentra
# la coincidencia pronto; pipefail los marcaria como falso-positivo de fallo.

set -eu

BASE="${1:-/tmp/ans-07-01}"
SITE="$BASE/site.yml"
fail=0

echo "== Validating ans-07-01 in $BASE =="

if [ ! -f "$SITE" ]; then
  echo "FAIL: $SITE no existe. Copia el starter y edita."
  exit 1
fi

# Sanity: ansible-playbook en PATH.
if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "FAIL: ansible-playbook no esta en PATH. Instala ansible-core (pipx install ansible)."
  exit 1
fi

# YAML parseable (via python).
if ! python3 -c "import sys, yaml; yaml.safe_load(open('$SITE'))" >/dev/null 2>&1; then
  echo "  FAIL site.yml no es YAML valido"
  fail=$((fail+1))
else
  echo "  OK   site.yml es YAML valido"
fi

# Construcciones requeridas.
for pattern_label in \
  "creates:|creates" \
  "changed_when:|changed_when" \
  "failed_when:|failed_when" \
  "check_mode:|check_mode" \
  "^[[:space:]]*block:|block" \
  "^[[:space:]]*rescue:|rescue" \
  "^[[:space:]]*always:|always"
do
  pattern="${pattern_label%|*}"
  label="${pattern_label##*|}"
  if grep -qE "$pattern" "$SITE"; then
    echo "  OK   usa '$label'"
  else
    echo "  FAIL falta '$label'"
    fail=$((fail+1))
  fi
done

echo
echo "-- Corriendo playbook (1a vez) --"
cd "$BASE"
if ! ansible-playbook site.yml >/tmp/ans-07-01.run1.log 2>&1; then
  echo "  FAIL 1a corrida reporto error. Log en /tmp/ans-07-01.run1.log"
  tail -30 /tmp/ans-07-01.run1.log || true
  fail=$((fail+1))
else
  echo "  OK   1a corrida termino sin error"
fi

echo "-- Corriendo playbook (2a vez — idempotencia) --"
if ! ansible-playbook site.yml >/tmp/ans-07-01.run2.log 2>&1; then
  echo "  FAIL 2a corrida reporto error. Log en /tmp/ans-07-01.run2.log"
  tail -30 /tmp/ans-07-01.run2.log || true
  fail=$((fail+1))
else
  # El recap es la ultima linea con "changed=". Buscamos changed=0.
  recap=$(grep -E 'changed=[0-9]+' /tmp/ans-07-01.run2.log | tail -1 || true)
  if echo "$recap" | grep -qE 'changed=0\b'; then
    echo "  OK   2a corrida reporto changed=0 ($recap)"
  else
    echo "  FAIL 2a corrida no es idempotente: $recap"
    fail=$((fail+1))
  fi
fi

echo "-- Corriendo playbook --check --diff --"
if ! ansible-playbook site.yml --check --diff >/tmp/ans-07-01.check.log 2>&1; then
  echo "  FAIL --check --diff reporto error. Log en /tmp/ans-07-01.check.log"
  tail -30 /tmp/ans-07-01.check.log || true
  fail=$((fail+1))
else
  echo "  OK   --check --diff termino sin error"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s)."
  exit 1
fi
echo "RESULT: 0 issue(s). site.yml es idempotente y usa todas las palancas requeridas."
exit 0
