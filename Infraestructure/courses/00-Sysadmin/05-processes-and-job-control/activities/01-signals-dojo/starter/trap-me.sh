#!/usr/bin/env bash
# trap-me.sh — STARTER
#
# TAREA: instala traps para que este script:
#   - En TERM, INT, HUP: imprima "SHUTDOWN: <SIGNAL>" y salga con 0.
#   - En USR1: imprima "RELOAD: config" y siga corriendo.
#   - En USR2: imprima "STATUS: ticks=<N>" y siga corriendo.
#   - En EXIT (del shell): imprima "CLEANUP: tempdir=<ruta>" SIEMPRE.
#
# No modifiques la seccion "no tocar" (loop principal y tempdir).
# Soporta: ./trap-me.sh [--pid-file RUTA]

set -euo pipefail

PID_FILE=""
while (( $# > 0 )); do
  case "$1" in
    --pid-file) PID_FILE="$2"; shift 2 ;;
    *) echo "arg desconocido: $1" >&2; exit 2 ;;
  esac
done

# ---- no tocar ----
TMPDIR_LOCAL="$(mktemp -d -t trap-me.XXXXXX)"
TICKS=0
# ------------------

if [[ -n "${PID_FILE}" ]]; then
  echo "$$" > "${PID_FILE}"
fi

# TODO: define las funciones graceful_shutdown, reload_config, print_status, cleanup
# TODO: instala los traps correspondientes

# ---- no tocar: loop principal ----
while :; do
  TICKS=$((TICKS + 1))
  echo "tick ${TICKS}"
  sleep 1
done
