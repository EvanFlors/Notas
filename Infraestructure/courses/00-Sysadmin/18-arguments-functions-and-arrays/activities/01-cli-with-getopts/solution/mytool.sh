#!/usr/bin/env bash
#
# mytool.sh — solución de referencia (sys-18-01)
#
set -euo pipefail
IFS=$'\n\t'

readonly PROG="${0##*/}"
readonly VERSION="1.0.0"

usage() {
    cat <<EOF
Uso: $PROG [-v] [-o FILE] [-n COUNT] [-h] [--] ARG

Opciones:
  -h            Muestra esta ayuda y sale (exit 0)
  -v            Modo verbose (log a stderr)
  -o FILE       Archivo de salida (requerido)
  -n COUNT      Entero positivo, default: 1

Posicionales:
  ARG           Valor a procesar

Exit codes:
  0  éxito o -h
  1  error de ejecución (no usado en este tool)
  2  error de uso
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    usage >&2
    exit 2
}

main() {
    local verbose=0
    local output=""
    local count=1
    local OPTIND=1 opt

    while getopts ":ho:vn:" opt; do
        case "$opt" in
            h) usage; exit 0 ;;
            v) verbose=1 ;;
            o) output="$OPTARG" ;;
            n) count="$OPTARG" ;;
            \?) die "opción desconocida: -$OPTARG" ;;
            :)  die "la opción -$OPTARG requiere argumento" ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ -n "$output" ]] || die "la opción -o FILE es obligatoria"
    [[ "$count" =~ ^[0-9]+$ ]] || die "COUNT debe ser entero no negativo"
    (( count > 0 )) || die "COUNT debe ser > 0"
    (( $# >= 1 )) || die "falta ARG posicional"

    local arg="$1"

    if (( verbose )); then
        printf '[verbose] arg=%s output=%s count=%d\n' \
            "$arg" "$output" "$count" >&2
    fi

    local i
    for ((i = 1; i <= count; i++)); do
        printf 'iter %d: %s -> %s\n' "$i" "$arg" "$output"
    done
}

main "$@"
