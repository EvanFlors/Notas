#!/usr/bin/env bash
# Validate: student completed sys-01-02-io-redirection-dojo correctly.
# Usage:
#   bash validate.sh [DOJO_DIR]
# Env overrides:
#   DOJO_DIR  (default /tmp/dojo)

set -o pipefail

DOJO="${1:-${DOJO_DIR:-/tmp/dojo}}"
fail=0

echo "== Validating artifacts at: $DOJO =="

if [ ! -d "$DOJO" ]; then
  echo "FAIL: workspace does not exist: $DOJO"
  exit 1
fi

check_nonempty() {
  local f="$1"
  if [ -s "$DOJO/$f" ]; then
    echo "  OK   $f existe y no vacío"
  else
    echo "  FAIL $f ausente o vacío"
    fail=$((fail+1))
  fi
}

check_contains() {
  local f="$1" pat="$2"
  if [ -f "$DOJO/$f" ] && grep -qE "$pat" "$DOJO/$f"; then
    echo "  OK   $f contiene patrón: $pat"
  else
    echo "  FAIL $f no contiene patrón: $pat"
    fail=$((fail+1))
  fi
}

# Ex 1
check_nonempty 01-stdout.txt

# Ex 2
check_nonempty 02-ok.txt
check_nonempty 02-err.txt
if [ -f "$DOJO/02-err.txt" ] && grep -qiE 'no.*such|cannot access|no existe' "$DOJO/02-err.txt"; then
  echo "  OK   02-err.txt contiene mensaje de error"
else
  echo "  FAIL 02-err.txt no parece contener error de ls"
  fail=$((fail+1))
fi

# Ex 3
check_nonempty 03-combo.txt
if [ -f "$DOJO/03-combo.txt" ] && grep -qiE 'no.*such|cannot access|no existe' "$DOJO/03-combo.txt"; then
  echo "  OK   03-combo.txt contiene stderr combinado"
else
  echo "  FAIL 03-combo.txt no combina stderr"
  fail=$((fail+1))
fi

# Ex 4
if [ -f "$DOJO/04-log.txt" ]; then
  lines=$(wc -l < "$DOJO/04-log.txt" | tr -d ' ')
  if [ "$lines" -ge 3 ]; then
    echo "  OK   04-log.txt tiene $lines líneas (>=3)"
  else
    echo "  FAIL 04-log.txt tiene $lines líneas (esperado >=3)"
    fail=$((fail+1))
  fi
  check_contains 04-log.txt '^inicio:'
  check_contains 04-log.txt '^fin:'
else
  echo "  FAIL 04-log.txt no existe"
  fail=$((fail+1))
fi

# Ex 5 — contenido literal
if [ -f "$DOJO/05-template.txt" ]; then
  if grep -qxF '# Template' "$DOJO/05-template.txt" \
     && grep -qxF 'usuario: $USER' "$DOJO/05-template.txt" \
     && grep -qxF 'home: $HOME' "$DOJO/05-template.txt"; then
    echo "  OK   05-template.txt contiene literales \$USER y \$HOME"
  else
    echo "  FAIL 05-template.txt no contiene los literales esperados"
    fail=$((fail+1))
  fi
else
  echo "  FAIL 05-template.txt no existe"
  fail=$((fail+1))
fi

# Ex 6 — exit code != 0
if [ -f "$DOJO/06-pipeline.txt" ]; then
  val=$(tr -d '[:space:]' < "$DOJO/06-pipeline.txt")
  if [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -ne 0 ]; then
    echo "  OK   06-pipeline.txt contiene exit code $val (!= 0)"
  else
    echo "  FAIL 06-pipeline.txt contenido inválido o 0: '$val'"
    fail=$((fail+1))
  fi
else
  echo "  FAIL 06-pipeline.txt no existe"
  fail=$((fail+1))
fi

# Ex 7
if [ -f "$DOJO/07-tee.txt" ]; then
  lines=$(wc -l < "$DOJO/07-tee.txt" | tr -d ' ')
  if [ "$lines" -ge 1 ] && [ "$lines" -le 5 ]; then
    echo "  OK   07-tee.txt tiene $lines líneas"
  else
    echo "  FAIL 07-tee.txt tiene $lines líneas (esperado 1..5)"
    fail=$((fail+1))
  fi
else
  echo "  FAIL 07-tee.txt no existe"
  fail=$((fail+1))
fi

# Ex 8
if [ -f "$DOJO/08-env.txt" ] && grep -qxF 'DOJO_VAR=exported' "$DOJO/08-env.txt"; then
  echo "  OK   08-env.txt propaga la variable exportada"
else
  echo "  FAIL 08-env.txt no contiene DOJO_VAR=exported"
  fail=$((fail+1))
fi

if [ -f "$DOJO/08-shell.txt" ] && grep -qxF 'DOJO_VAR=UNSET' "$DOJO/08-shell.txt"; then
  echo "  OK   08-shell.txt confirma que shell var no se propaga"
else
  echo "  FAIL 08-shell.txt no contiene DOJO_VAR=UNSET"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
