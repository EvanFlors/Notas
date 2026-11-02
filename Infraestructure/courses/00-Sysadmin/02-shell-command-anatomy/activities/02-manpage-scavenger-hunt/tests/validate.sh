#!/usr/bin/env bash
# Validación automática para sys-02-02-manpage-scavenger-hunt.
# Comprueba estructura y respuestas exactas (10 preguntas de hechos verificables).
set -euo pipefail

WORK="${1:-/tmp/manpage-hunt}"
FILE="$WORK/answers.md"
fail=0

echo "== Validación para $WORK =="

if [[ ! -f "$FILE" ]]; then
  echo "FAIL: no existe $FILE"
  exit 1
fi

# Extrae la respuesta de un bloque dado por "## Pn".
# Devuelve el contenido tras "respuesta:" en minúsculas y sin backticks/asteriscos/espacios extremos.
get_answer() {
  local qid="$1"
  awk -v q="## $qid" '
    $0 ~ "^"q"[[:space:]]*$" {found=1; next}
    found && /^## P/ {exit}
    found && /respuesta:/ {
      sub(/^.*respuesta:[[:space:]]*/, "")
      gsub(/[`*]/, "")
      print tolower($0)
      exit
    }
  ' "$FILE" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

# Devuelve 0 si la respuesta del estudiante contiene cualquiera de los patrones aceptados.
# Uso: match_any "respuesta_estudiante" "pat1" "pat2" ...
match_any() {
  local answer="$1"; shift
  local pat
  for pat in "$@"; do
    if [[ "$answer" == *"$pat"* ]]; then
      return 0
    fi
  done
  return 1
}

check() {
  local qid="$1"; shift
  local label="$1"; shift
  local ans
  ans="$(get_answer "$qid")"
  if [[ -z "$ans" ]]; then
    echo "  FAIL $qid sin respuesta."
    fail=$((fail+1))
    return
  fi
  if match_any "$ans" "$@"; then
    echo "  OK   $qid ($label)"
  else
    echo "  FAIL $qid: '$ans' no coincide con ninguna de las esperadas ($*)"
    fail=$((fail+1))
  fi
}

# Presencia de los 10 bloques.
for n in 1 2 3 4 5 6 7 8 9 10; do
  if grep -Eq "^## *P${n}([^0-9]|$)" "$FILE"; then
    :
  else
    echo "  FAIL bloque ## P${n} ausente"
    fail=$((fail+1))
  fi
done

check "P1"  "sección 5"         "5"
check "P2"  "grep -l"           "-l"
check "P3"  "tar --directory"   "--directory"
check "P4"  "LC_COLLATE"        "lc_collate" "lc_all"
check "P5"  "curl exit 22"      "22"
check "P6"  "find -mtime -1"    "-mtime -1" "-mtime-1"
check "P7"  "IdentityFile"      "identityfile"
check "P8"  "ExecStart"         "execstart"
check "P9"  "rsync -a"          "-a"
check "P10" "SIGKILL = 9"       "9"

echo
if [[ "$fail" -gt 0 ]]; then
  echo "RESULT: $fail chequeo(s) fallaron."
  exit 1
fi
echo "OK: las 10 respuestas son correctas."
exit 0
