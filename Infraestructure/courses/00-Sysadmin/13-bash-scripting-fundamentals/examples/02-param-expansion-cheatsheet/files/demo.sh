#!/usr/bin/env bash
#
# demo.sh — muestra las cuatro expansiones de parametros con default.

set -uo pipefail

printf '\n== 1. ${var:-default}  (usa default, NO asigna) ==\n'
unset color
printf 'color antes: %s\n' "${color:-<no definido>}"
printf 'expresion   : color=%s\n' "${color:-rojo}"
printf 'color despues: %s\n' "${color:-<no definido>}"

printf '\n== 2. ${var:=default}  (usa default Y asigna) ==\n'
unset color
printf 'color antes: %s\n' "${color:-<no definido>}"
printf 'expresion   : color=%s\n' "${color:=azul}"
printf 'color despues: %s\n' "${color:-<no definido>}"

printf '\n== 3. ${var:?msg}  (aborta si vacia/no definida) ==\n'
color="verde"
printf 'con valor: %s\n' "${color:?color obligatorio}"
printf '(si quieres ver el abort, ejecuta: %s --test-abort)\n' "$0"

printf '\n== 4. ${var:+alt}  (expande a alt solo si var tiene valor) ==\n'
unset flag
printf 'flag no definida -> [%s]\n' "${flag:+-v}"
flag="1"
printf 'flag definida    -> [%s]\n' "${flag:+-v}"

if [[ "${1:-}" == "--test-abort" ]]; then
  printf '\n== BONUS: forzando abort con :? ==\n'
  set -e
  unset missing
  : "${missing:?variable missing es obligatoria}"
  printf 'esta linea NO se imprime\n'
fi
