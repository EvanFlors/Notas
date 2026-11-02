#!/usr/bin/env bash
# demo.sh — supervisor + worker con trap y wait.
# Didactico. No usar en produccion sin ajustar logging y escalada.

set -euo pipefail

GRACE_SECONDS="${GRACE_SECONDS:-5}"
TICKS="${TICKS:-10}"

shutdown=0
on_signal() { shutdown=1; }
trap on_signal TERM INT HUP

worker() {
  # Hijo: imprime un tick por segundo hasta TICKS, o hasta que lo maten.
  trap 'echo "worker: TERM recibido, saliendo limpio"; exit 0' TERM
  local i
  for ((i = 1; i <= TICKS; i++)); do
    echo "worker: tick ${i}/${TICKS} (pid=$$ ppid=${PPID})"
    sleep 1
  done
  echo "worker: trabajo completado"
}

worker &
WORKER_PID=$!

echo "supervisor PID=$$ worker PID=${WORKER_PID}"
echo "pulsa Ctrl-C o envia TERM a ${$} para probar graceful shutdown"

# Loop supervisado: no bloquea en wait para poder reaccionar a la bandera.
while (( shutdown == 0 )); do
  if ! kill -0 "${WORKER_PID}" 2>/dev/null; then
    echo "supervisor: worker termino por su cuenta"
    break
  fi
  sleep 1
done

if (( shutdown == 1 )); then
  echo "supervisor: senal recibida, drenando (grace=${GRACE_SECONDS}s)"
  kill -TERM "${WORKER_PID}" 2>/dev/null || true
  for ((i = 0; i < GRACE_SECONDS; i++)); do
    kill -0 "${WORKER_PID}" 2>/dev/null || break
    sleep 1
  done
  if kill -0 "${WORKER_PID}" 2>/dev/null; then
    echo "supervisor: worker no colaboro, escalando a KILL"
    kill -KILL "${WORKER_PID}" 2>/dev/null || true
  fi
fi

wait "${WORKER_PID}" 2>/dev/null || true
echo "supervisor: exit"
