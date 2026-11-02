#!/usr/bin/env bash
#
# mytool.sh — starter de la actividad sys-18-01
#
# Completa los TODO marcados abajo. Lee README.md antes de empezar.
#
set -euo pipefail
IFS=$'\n\t'

readonly PROG="${0##*/}"

usage() {
    # TODO: imprime a stdout la ayuda del tool, siguiendo el formato
    # mostrado en README.md.  Incluye las opciones, los posicionales y
    # los exit codes.
    cat <<EOF
Uso: $PROG [-v] [-o FILE] [-n COUNT] [-h] [--] ARG

(TODO: completa esta ayuda)
EOF
}

die() {
    # TODO: imprime "Error: <mensaje>" a stderr, luego imprime usage a
    # stderr, y sale con exit code 2.
    :
}

main() {
    local verbose=0
    local output=""
    local count=1

    # TODO: implementa el bucle getopts con la cadena ":ho:vn:" (silent mode).
    # Maneja:
    #   h) usage; exit 0
    #   v) activa verbose
    #   o) guarda OPTARG en output
    #   n) guarda OPTARG en count
    #   \?) opción desconocida -> die
    #   :) opción sin argumento -> die

    # TODO: shift $((OPTIND - 1))

    # TODO: validaciones
    #   - output no vacío
    #   - count es entero y > 0
    #   - al menos un posicional

    local arg="${1:-}"   # (ajusta cuando valides)

    if (( verbose )); then
        printf '[verbose] arg=%s output=%s count=%d\n' \
            "$arg" "$output" "$count" >&2
    fi

    # TODO: "trabajo" simulado — imprime a stdout:
    #   iter <i>: <arg> -> <output>
    # para i = 1..count
}

main "$@"
