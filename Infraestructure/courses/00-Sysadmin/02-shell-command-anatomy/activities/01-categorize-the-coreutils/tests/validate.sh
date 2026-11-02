#!/usr/bin/env bash
# Validación estructural para sys-02-01-categorize-the-coreutils.
# Comprueba que classification.md existe, lista las 40 filas y usa categorías válidas.
set -euo pipefail

WORK="${1:-/tmp/categorize-coreutils}"
FILE="$WORK/classification.md"
fail=0

echo "== Validación estructural para $WORK =="

if [[ ! -f "$FILE" ]]; then
  echo "FAIL: no existe $FILE"
  exit 1
fi

# 40 comandos esperados (deben aparecer como primera celda en una fila de tabla).
commands=(
  ls cp rm find grep sed awk cut sort uniq wc head tail cat less xxd
  ps top kill nice ss ip curl dig chmod chown sudo id apt dnf systemctl
  journalctl df du lsblk tar gzip sha256sum gpg type
)

missing=0
for c in "${commands[@]}"; do
  # Acepta "| ls " o "| ls|" o "|ls " dentro de la tabla.
  if grep -Eq "^\|[[:space:]]*${c}[[:space:]]*\|" "$FILE"; then
    :
  else
    echo "  FAIL comando ausente en tabla: $c"
    missing=$((missing+1))
  fi
done
if [[ "$missing" -eq 0 ]]; then
  echo "  OK   los 40 comandos aparecen como filas de tabla"
else
  fail=$((fail+missing))
fi

# Categorías canónicas (substring match, case-insensitive).
categories=(
  "Navegaci" "Manipulaci" "Lectura" "Edici" "Búsqueda" "Procesos"
  "Red" "Usuarios" "Paquetes" "Servicios" "Disco" "Archivadores"
  "Checksums" "Meta"
)
found_cat=0
for cat in "${categories[@]}"; do
  if grep -qi "$cat" "$FILE"; then
    found_cat=$((found_cat+1))
  fi
done
if [[ "$found_cat" -ge 12 ]]; then
  echo "  OK   usa al menos 12/14 categorías canónicas ($found_cat)"
else
  echo "  FAIL sólo encuentra $found_cat/14 categorías canónicas (mín. 12)"
  fail=$((fail+1))
fi

# Debe tener una sección de Preguntas con al menos 5 numeradas.
if grep -qi "^## *Preguntas" "$FILE"; then
  echo "  OK   sección '## Preguntas' presente"
else
  echo "  FAIL falta sección '## Preguntas'"
  fail=$((fail+1))
fi

answered=0
for n in 1 2 3 4 5; do
  if grep -Eq "^${n}\." "$FILE"; then
    answered=$((answered+1))
  fi
done
if [[ "$answered" -ge 5 ]]; then
  echo "  OK   las 5 preguntas aparecen numeradas"
else
  echo "  FAIL sólo $answered/5 preguntas numeradas detectadas"
  fail=$((fail+1))
fi

echo
if [[ "$fail" -gt 0 ]]; then
  echo "RESULT: $fail chequeo(s) fallaron. Compara con solution/README.md."
  exit 1
fi
echo "OK: estructura válida. Compara con solution/README.md para autoevaluarte."
exit 0
