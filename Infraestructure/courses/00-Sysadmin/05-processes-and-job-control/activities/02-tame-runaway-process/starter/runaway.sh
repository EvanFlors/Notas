#!/usr/bin/env bash
# runaway.sh — proceso "mal portado" que ignora SIGTERM.
# DIDACTICO. No ejecutar sin control: solo KILL lo puede parar.
set -euo pipefail

LOG="/tmp/runaway.log"
while (( $# > 0 )); do
  case "$1" in
    --log) LOG="$2"; shift 2 ;;
    *) echo "arg desconocido: $1" >&2; exit 2 ;;
  esac
done

: >"${LOG}"

log() {
  printf '%s [pid=%d] %s\n' "$(date -u +%FT%TZ)" "$$" "$*" >>"${LOG}"
}

# Ignora TERM, INT y HUP: lo mas rudo posible sin dejar de ser bash.
on_term() {
  log "received SIGTERM — IGNORING (mal portado)"
}
on_int() {
  log "received SIGINT — IGNORING"
}
on_hup() {
  log "received SIGHUP — IGNORING"
}
trap on_term TERM
trap on_int  INT
trap on_hup  HUP

log "runaway start"

# Bucle apretado: no bloquea en IO, solo CPU + sleep corto para no fundir el host.
i=0
while :; do
  i=$((i + 1))
  if (( i % 1000 == 0 )); then
    log "still running i=${i}"
  fi
  # Pequena pausa para no quemar la CPU en la demo.
  sleep 0.05
done
