#!/usr/bin/env bash
# demo.sh — matriz imprimible de operadores de test en Bash.
# Crea archivos de prueba, evalúa cada operador y muestra V/F.
set -euo pipefail

TMP="$(mktemp -d -t sys15-matrix-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# ----- Preparar artefactos -----
regular="$TMP/regular.txt"
vacio="$TMP/empty.txt"
directorio="$TMP/dir"
enlace="$TMP/link"
no_ejec="$TMP/no-exec.sh"

echo "contenido" > "$regular"
: > "$vacio"
mkdir -p "$directorio"
ln -s "$regular" "$enlace"
echo "echo hola" > "$no_ejec"   # sin bit +x

# Helper: imprime "V" o "F" según el exit code del condicional.
check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '  %-55s -> V\n' "$label"
  else
    printf '  %-55s -> F\n' "$label"
  fi
}

echo "== Operadores de archivo =="
check "[[ -e regular ]]"           bash -c "[[ -e '$regular' ]]"
check "[[ -e inexistente ]]"       bash -c "[[ -e '$TMP/nope' ]]"
check "[[ -f regular ]]"           bash -c "[[ -f '$regular' ]]"
check "[[ -f directorio ]]"        bash -c "[[ -f '$directorio' ]]"
check "[[ -d directorio ]]"        bash -c "[[ -d '$directorio' ]]"
check "[[ -h symlink ]]"           bash -c "[[ -h '$enlace' ]]"
check "[[ -r regular ]]"           bash -c "[[ -r '$regular' ]]"
check "[[ -w regular ]]"           bash -c "[[ -w '$regular' ]]"
check "[[ -x regular (sin +x) ]]"  bash -c "[[ -x '$regular' ]]"
check "[[ -x /bin/sh ]]"           bash -c "[[ -x /bin/sh ]]"
check "[[ -s regular ]]"           bash -c "[[ -s '$regular' ]]"
check "[[ -s empty ]]"             bash -c "[[ -s '$vacio' ]]"

echo
echo "== Operadores de string =="
check '[[ -z "" ]]'                bash -c '[[ -z "" ]]'
check '[[ -z "hola" ]]'            bash -c '[[ -z "hola" ]]'
check '[[ -n "hola" ]]'            bash -c '[[ -n "hola" ]]'
check '[[ -n "" ]]'                bash -c '[[ -n "" ]]'
check '[[ "007" = "7" ]]'          bash -c '[[ "007" = "7" ]]'
check '[[ "abc" != "abd" ]]'       bash -c '[[ "abc" != "abd" ]]'
check '[[ "app.log" == *.log ]]'   bash -c '[[ "app.log" == *.log ]]'
check '[[ "readme.md" == *.log ]]' bash -c '[[ "readme.md" == *.log ]]'
check '[[ "error 42" =~ ^error ]]' bash -c '[[ "error 42" =~ ^error ]]'
check '[[ "info 42" =~ ^error ]]'  bash -c '[[ "info 42" =~ ^error ]]'

echo
echo "== Operadores numéricos (test) =="
check '[[ 7 -eq 7 ]]'              bash -c '[[ 7 -eq 7 ]]'
check '[[ "007" -eq 7 ]]'          bash -c '[[ "007" -eq 7 ]]'
check '[[ 7 -ne 8 ]]'              bash -c '[[ 7 -ne 8 ]]'
check '[[ 3 -lt 5 ]]'              bash -c '[[ 3 -lt 5 ]]'
check '[[ 5 -le 5 ]]'              bash -c '[[ 5 -le 5 ]]'
check '[[ 9 -gt 2 ]]'              bash -c '[[ 9 -gt 2 ]]'
check '[[ 9 -ge 9 ]]'              bash -c '[[ 9 -ge 9 ]]'

echo
echo "== Comparaciones aritméticas (( )) =="
check '(( 7 == 7 ))'               bash -c '(( 7 == 7 ))'
check '(( 3 < 5 ))'                bash -c '(( 3 < 5 ))'
check '(( 5 <= 5 ))'               bash -c '(( 5 <= 5 ))'
check '(( 9 != 9 ))'               bash -c '(( 9 != 9 ))'
check '(( 2 + 3 == 5 ))'           bash -c '(( 2 + 3 == 5 ))'
check '(( 10 / 3 == 3 ))'          bash -c '(( 10 / 3 == 3 ))'   # entero
check '(( 10 % 3 == 1 ))'          bash -c '(( 10 % 3 == 1 ))'

echo
echo "FIN. Artefactos temporales eliminados por trap EXIT."
