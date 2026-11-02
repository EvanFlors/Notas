#!/usr/bin/env bash
# trap-me.sh — SOLUCION
set -euo pipefail

PID_FILE=""
while (( $# > 0 )); do
  case "$1" in
    --pid-file) PID_FILE="$2"; shift 2 ;;
    *) echo "arg desconocido: $1" >&2; exit 2 ;;
  esac
done

TMPDIR_LOCAL="$(mktemp -d -t trap-me.XXXXXX)"
TICKS=0

if [[ -n "${PID_FILE}" ]]; then
  echo "$$" > "${PID_FILE}"
fi

cleanup() {
  echo "CLEANUP: tempdir=${TMPDIR_LOCAL}"
  rm -rf "${TMPDIR_LOCAL}" 2>/dev/null || true
}

graceful_shutdown() {
  local sig="$1"
  # Evita re-entrada si llega otra senal mientras salimos.
  trap - TERM INT HUP
  echo "SHUTDOWN: ${sig}"
  exit 0
}

reload_config() {
  echo "RELOAD: config"
}

print_status() {
  echo "STATUS: ticks=${TICKS}"
}

trap cleanup EXIT
trap 'graceful_shutdown TERM' TERM
trap 'graceful_shutdown INT'  INT
trap 'graceful_shutdown HUP'  HUP
trap reload_config USR1
trap print_status  USR2

while :; do
  TICKS=$((TICKS + 1))
  echo "tick ${TICKS}"
  # 'sleep' en bash es interrumpible por senales; eso permite reaccionar rapido.
  sleep 1 &
  wait $! 2>/dev/null || true
done
