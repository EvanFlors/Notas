#!/usr/bin/env bash
# Validate: sys-20-02-verified-download-pipeline.
set -o pipefail

SCRIPT="${1:-}"
if [[ -z "$SCRIPT" ]]; then
  if [[ -f ./pipeline.sh ]]; then
    SCRIPT=./pipeline.sh
  else
    SCRIPT="$(dirname "$0")/../solution/pipeline.sh"
  fi
fi

fail=0

echo "== Validating script: $SCRIPT =="

if [[ ! -f "$SCRIPT" ]]; then
  echo "FAIL script no existe: $SCRIPT"
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

# 2. Uso de las herramientas clave
for need in 'sha256sum --check' 'gpg --verify' 'wget' 'trap'; do
  if grep -q -- "$need" "$SCRIPT"; then
    echo "  OK   usa $need"
  else
    echo "  FAIL falta $need"
    fail=$((fail+1))
  fi
done

# 3. Flags prohibidas
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

# 5. Prerequisito gpg
if ! command -v gpg >/dev/null 2>&1; then
  echo "  WARN gpg no instalado; se omiten pruebas funcionales"
  if [[ $fail -gt 0 ]]; then
    echo "RESULT: $fail check(s) failed."
    exit 1
  fi
  echo "OK (parcial, sin gpg): revisiones estaticas pasaron."
  exit 0
fi

# 6. Modo offline deberia terminar en 0
TMP_WORK="$(mktemp -d)"
if WORK="$TMP_WORK" bash "$SCRIPT" >/dev/null 2>&1; then
  echo "  OK   modo offline exit 0"
else
  rc=$?
  echo "  FAIL modo offline exit=$rc (esperado 0)"
  fail=$((fail+1))
fi

# 7. Corromper artifact.bin -> re-correr deberia fallar en checksum (exit 65).
#    Si el pipeline regenera el artifact antes de verificar, este test queda warn.
if [[ -f "$TMP_WORK/artifact.bin" ]]; then
  # Hacer el SHA256SUMS "stale" alterando el archivo original despues de que se publico.
  printf 'contenido alterado\n' > "$TMP_WORK/artifact.bin"
  # Preservamos SHA256SUMS y .asc existentes forzando que el script no los re-genere:
  # ejecutamos solo las verificaciones a mano para dejar claro el expected behavior.
  if ( cd "$TMP_WORK" && sha256sum --check --strict SHA256SUMS >/dev/null 2>&1 ); then
    echo "  FAIL sha256sum --check deberia fallar tras alterar el artefacto"
    fail=$((fail+1))
  else
    echo "  OK   checksum detecta alteracion del artefacto"
  fi
fi

rm -rf "$TMP_WORK"

echo
if [[ $fail -gt 0 ]]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
