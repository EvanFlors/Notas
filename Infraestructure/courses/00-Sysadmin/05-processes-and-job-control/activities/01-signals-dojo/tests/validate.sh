#!/usr/bin/env bash
# validate.sh — comprueba el signals-dojo.
# Uso: bash tests/validate.sh [RUTA_AL_SCRIPT]
# Default: /tmp/trap-me.sh

set -o pipefail

SCRIPT="${1:-/tmp/trap-me.sh}"
fail=0

echo "== Validating script: ${SCRIPT} =="

if [[ ! -x "${SCRIPT}" ]]; then
  if [[ -f "${SCRIPT}" ]]; then
    chmod +x "${SCRIPT}" || true
  else
    echo "FAIL: script no encontrado: ${SCRIPT}"
    exit 1
  fi
fi

run_case() {
  local label="$1" sig="$2" expect_pattern="$3" expect_alive="$4"
  local pidfile log pid
  pidfile="$(mktemp -t trap-me-pid.XXXXXX)"
  log="$(mktemp -t trap-me-log.XXXXXX)"

  "${SCRIPT}" --pid-file "${pidfile}" >"${log}" 2>&1 &
  local supervisor=$!
  # Esperar a que el script escriba su PID.
  for _ in {1..30}; do
    [[ -s "${pidfile}" ]] && break
    sleep 0.1
  done
  pid="$(cat "${pidfile}" 2>/dev/null || true)"
  if [[ -z "${pid}" ]]; then
    echo "  FAIL [${label}] no pid-file escrito"
    fail=$((fail+1))
    kill -KILL "${supervisor}" 2>/dev/null || true
    wait "${supervisor}" 2>/dev/null || true
    return
  fi

  # Dejar que avance al menos un tick.
  sleep 1.2
  kill -"${sig}" "${pid}" 2>/dev/null || true
  sleep 1.0

  if [[ "${expect_alive}" = "yes" ]]; then
    if kill -0 "${pid}" 2>/dev/null; then
      echo "  OK   [${label}] sigue vivo tras ${sig}"
    else
      echo "  FAIL [${label}] murio tras ${sig} y no deberia"
      fail=$((fail+1))
    fi
    # Terminamos nosotros para no dejar el proceso corriendo.
    kill -TERM "${pid}" 2>/dev/null || true
    sleep 0.5
    kill -KILL "${pid}" 2>/dev/null || true
  else
    # Esperamos que haya terminado.
    for _ in {1..20}; do
      kill -0 "${pid}" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "${pid}" 2>/dev/null; then
      echo "  FAIL [${label}] no murio tras ${sig}"
      fail=$((fail+1))
      kill -KILL "${pid}" 2>/dev/null || true
    else
      echo "  OK   [${label}] murio limpio tras ${sig}"
    fi
  fi

  wait "${supervisor}" 2>/dev/null || true

  if grep -Eq "${expect_pattern}" "${log}"; then
    echo "  OK   [${label}] log contiene /${expect_pattern}/"
  else
    echo "  FAIL [${label}] log no contiene /${expect_pattern}/"
    echo "  --- log ---"
    sed 's/^/    /' "${log}"
    echo "  -----------"
    fail=$((fail+1))
  fi

  # Siempre debe aparecer CLEANUP si murio.
  if [[ "${expect_alive}" = "no" ]]; then
    if grep -Eq '^CLEANUP: tempdir=' "${log}"; then
      echo "  OK   [${label}] CLEANUP registrado"
    else
      echo "  FAIL [${label}] CLEANUP no registrado"
      fail=$((fail+1))
    fi
  fi

  rm -f "${pidfile}" "${log}"
}

run_case "TERM"  TERM  '^SHUTDOWN: TERM$'   no
run_case "INT"   INT   '^SHUTDOWN: INT$'    no
run_case "HUP"   HUP   '^SHUTDOWN: HUP$'    no
run_case "USR1"  USR1  '^RELOAD: config$'   yes
run_case "USR2"  USR2  '^STATUS: ticks=[0-9]+$' yes

echo
if (( fail > 0 )); then
  echo "RESULT: ${fail} check(s) failed."
  exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
