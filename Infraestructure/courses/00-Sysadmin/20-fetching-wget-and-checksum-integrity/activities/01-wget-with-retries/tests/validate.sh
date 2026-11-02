#!/usr/bin/env bash
# Validate: sys-20-01-wget-with-retries.
# Pass SCRIPT path as first arg; defaults to ./fetch.sh then solution/fetch.sh.
set -o pipefail

SCRIPT="${1:-}"
if [[ -z "$SCRIPT" ]]; then
  if [[ -f ./fetch.sh ]]; then
    SCRIPT=./fetch.sh
  else
    SCRIPT="$(dirname "$0")/../solution/fetch.sh"
  fi
fi

fail=0

echo "== Validating script: $SCRIPT =="

if [[ ! -f "$SCRIPT" ]]; then
  echo "FAIL: script no existe: $SCRIPT"
  exit 1
fi

# 1. Shebang + set -euo pipefail
if head -1 "$SCRIPT" | grep -qE '^#!/usr/bin/env bash'; then
  echo "  OK   shebang bash"
else
  echo "  FAIL shebang incorrecto"
  fail=$((fail+1))
fi

if grep -qE 'set -euo pipefail' "$SCRIPT"; then
  echo "  OK   set -euo pipefail presente"
else
  echo "  FAIL set -euo pipefail ausente"
  fail=$((fail+1))
fi

# 2. Flags requeridas
for flag in '--continue' '--tries' '--waitretry' '--connect-timeout' '--read-timeout' '--retry-connrefused' '--output-document'; do
  if grep -q -- "$flag" "$SCRIPT"; then
    echo "  OK   usa $flag"
  else
    echo "  FAIL falta flag $flag"
    fail=$((fail+1))
  fi
done

# 3. Flags PROHIBIDAS
for bad in '--no-check-certificate' '--insecure' ' -k ' 'curl '; do
  if grep -qE "$bad" "$SCRIPT"; then
    echo "  FAIL contiene flag prohibida: $bad"
    fail=$((fail+1))
  else
    echo "  OK   sin $bad"
  fi
done

# 4. shellcheck
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning "$SCRIPT"; then
    echo "  OK   shellcheck -S warning limpio"
  else
    echo "  FAIL shellcheck encontro problemas"
    fail=$((fail+1))
  fi
else
  echo "  WARN shellcheck no instalado; skip"
fi

# 5. Exit 2 sin args
bash "$SCRIPT" >/dev/null 2>&1
rc=$?
if [[ $rc -eq 2 ]]; then
  echo "  OK   exit 2 sin argumentos"
else
  echo "  FAIL exit=$rc sin args (esperado 2)"
  fail=$((fail+1))
fi

# 6. Exit 69 ante URL inexistente (resolvible, 404)
TMPOUT="$(mktemp -d)/out.bin"
bash "$SCRIPT" "https://ftp.gnu.org/gnu/hello/NO-EXISTE-sys20.tar.gz" "$TMPOUT" >/dev/null 2>&1
rc=$?
if [[ $rc -eq 69 ]]; then
  echo "  OK   exit 69 ante URL 404"
else
  echo "  WARN exit=$rc ante URL inexistente (esperado 69; puede variar sin red)"
fi

# 7. Descarga real (requiere red). Si falla por red, no cuenta como fail duro.
TMPOUT2="$(mktemp -d)/hello.tar.gz"
if bash "$SCRIPT" "https://ftp.gnu.org/gnu/hello/hello-2.12.tar.gz" "$TMPOUT2" >/dev/null 2>&1; then
  if [[ -s "$TMPOUT2" ]]; then
    echo "  OK   descarga real exitosa ($TMPOUT2)"
  else
    echo "  FAIL descarga vacia"
    fail=$((fail+1))
  fi
else
  echo "  WARN descarga real fallo (red?); no se cuenta como error duro"
fi

echo
if [[ $fail -gt 0 ]]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
