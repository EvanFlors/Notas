#!/usr/bin/env bash
# template.sh — esqueleto reusable para jobs robustos.
# Variables de entorno de prueba:
#   FAIL=1   → fuerza un fallo a mitad para ver el handler ERR.
#   SLEEP=N  → duerme N segundos (útil para probar Ctrl-C).
# Exit codes: 0 ok | 70 bug | 130 SIGINT | 143 SIGTERM.
set -euo pipefail
IFS=$'\n\t'

# ---- constantes ----
readonly SCRIPT_NAME=${0##*/}
readonly EX_SOFTWARE=70

# ---- logging (todo a stderr; stdout queda libre para datos) ----
_log() {
    local level=$1; shift
    printf '[%s] %s %s %s\n' "$(date +'%FT%T%z')" "$level" "$SCRIPT_NAME" "$*" >&2
}
log_info()  { _log INFO  "$@"; }
log_warn()  { _log WARN  "$@"; }
log_error() { _log ERROR "$@"; }

# ---- estado que requiere cleanup ----
tmpdir=""

# ---- handlers ----
cleanup() {
    local rc=$?
    if [[ -n "$tmpdir" && -d "$tmpdir" ]]; then
        rm -rf "$tmpdir"
        log_info "cleanup: tmpdir eliminado"
    fi
    exit "$rc"
}

on_err() {
    local rc=$?
    local line=${BASH_LINENO[0]}
    local cmd=${BASH_COMMAND}
    log_error "línea $line: \"$cmd\" (exit $rc)"
}

on_int()  { log_warn "SIGINT recibido";  exit 130; }
on_term() { log_warn "SIGTERM recibido"; exit 143; }

trap cleanup EXIT
trap on_err  ERR
trap on_int  INT
trap on_term TERM

# ---- cuerpo ----
main() {
    tmpdir=$(mktemp -d)
    log_info "tmpdir=$tmpdir"

    if [[ -n "${SLEEP:-}" ]]; then
        log_info "durmiendo ${SLEEP}s (pulsa Ctrl-C para probar INT)"
        sleep "$SLEEP"
    fi

    if [[ "${FAIL:-}" == "1" ]]; then
        log_info "FAIL=1 → forzando fallo"
        false   # dispara ERR + aborta por -e; cleanup corre vía EXIT
    fi

    # trabajo "real" (demostración):
    echo "hola mundo" > "$tmpdir/output.txt"
    log_info "escribí $tmpdir/output.txt ($(wc -c < "$tmpdir/output.txt") bytes)"

    log_info "done"
}

main "$@"
