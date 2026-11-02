#!/usr/bin/env bash
# job.sh (SOLUTION) — genera un reporte y lo copia a OUT_DIR de forma robusta.
#
# Variables:
#   OUT_DIR : directorio destino (default /tmp/sys14-out)
#   SLOW    : si está set, duerme N segundos (prueba concurrencia / señales)
#
# Exit codes:
#   0   ok
#   70  bug interno (EX_SOFTWARE)
#   73  no se pudo crear OUT_DIR (EX_CANTCREAT)
#   75  otra instancia ya corriendo (EX_TEMPFAIL)
#   130 interrumpido por SIGINT
#   143 interrumpido por SIGTERM

set -euo pipefail
IFS=$'\n\t'

# ---- constantes ----
readonly SCRIPT_NAME=${0##*/}
readonly OUT_DIR=${OUT_DIR:-/tmp/sys14-out}
readonly LOCK_FILE=${LOCK_FILE:-/tmp/sys14-job.lock}
readonly EX_SOFTWARE=70
readonly EX_CANTCREAT=73
readonly EX_TEMPFAIL=75

# ---- logging (stderr; stdout queda libre para datos) ----
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

# ---- lock ----
# Abrimos el fd 9 apuntando al lock file. flock lo asocia con fd.
# Cuando el shell termine (por cualquier vía) el kernel cierra el fd
# y libera el lock automáticamente. Sobrevive incluso a SIGKILL.
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    log_warn "otra instancia corriendo; saliendo."
    exit "$EX_TEMPFAIL"
fi

# ---- cuerpo ----
main() {
    if ! mkdir -p "$OUT_DIR"; then
        log_error "no pude crear OUT_DIR=$OUT_DIR"
        exit "$EX_CANTCREAT"
    fi

    tmpdir=$(mktemp -d /tmp/job-tmp.XXXXXX)
    log_info "tmpdir=$tmpdir"

    # trabajo "real" (demostración)
    printf 'reporte generado %s\n' "$(date)" > "$tmpdir/report.txt"

    if [[ -n "${SLOW:-}" ]]; then
        log_info "SLOW=${SLOW}s"
        sleep "$SLOW"
    fi

    cp "$tmpdir/report.txt" "$OUT_DIR/report.txt"
    log_info "escrito en $OUT_DIR/report.txt"
}

main "$@"
log_info "done"
exit 0
