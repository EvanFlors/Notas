#!/usr/bin/env bash
# Valida que broken.service fue reparado y está activo.
set -o pipefail

UNIT="broken.service"
UNIT_PATH="/etc/systemd/system/${UNIT}"

fail=0

say_ok()   { echo "  OK   $*"; }
say_fail() { echo "  FAIL $*"; fail=$((fail + 1)); }

echo "== Validando ${UNIT} =="

if ! command -v systemctl >/dev/null 2>&1; then
  echo "FAIL: systemctl no disponible."
  exit 1
fi

if [[ ! -f "${UNIT_PATH}" ]]; then
  say_fail "${UNIT_PATH} no existe. ¿Instalaste la unidad?"
  echo
  echo "RESULT: ${fail} fallo(s)."
  exit 1
fi
say_ok "${UNIT_PATH} existe"

# verify limpio
verify_out="$(systemd-analyze verify "${UNIT_PATH}" 2>&1 || true)"
if [[ -n "${verify_out}" ]]; then
  say_fail "systemd-analyze verify sigue reportando:"
  echo "${verify_out}" | sed 's/^/      /'
else
  say_ok "systemd-analyze verify limpio"
fi

# ExecStart absoluto
exec_line="$(grep -E '^ExecStart=' "${UNIT_PATH}" | head -1 | cut -d= -f2-)"
first_token="${exec_line%% *}"
# Permite prefijos @ - : ! como define systemd
first_token="${first_token#@}"
first_token="${first_token#-}"
first_token="${first_token#:}"
first_token="${first_token#!}"
first_token="${first_token#!}"
if [[ "${first_token}" == /* ]]; then
  say_ok "ExecStart usa ruta absoluta (${first_token})"
else
  say_fail "ExecStart no es absoluto: '${exec_line}'"
fi

# Estado
active="$(systemctl is-active "${UNIT}" 2>/dev/null || echo unknown)"
if [[ "${active}" == "active" ]]; then
  say_ok "is-active=active"
else
  say_fail "is-active=${active} (reintenta: sudo systemctl daemon-reload && sudo systemctl restart ${UNIT})"
fi

echo
if [[ "${fail}" -gt 0 ]]; then
  echo "RESULT: ${fail} fallo(s)."
  exit 1
fi
echo "OK: broken.service está activo y verify limpio."
exit 0
