#!/usr/bin/env bash
# Valida que sys07-app.service cumple los requisitos del lab.
# Exits 0 si OK, 1 si no.
set -o pipefail

UNIT="sys07-app.service"
UNIT_PATH="/etc/systemd/system/${UNIT}"

fail=0
warn=0

say_ok()   { echo "  OK   $*"; }
say_fail() { echo "  FAIL $*"; fail=$((fail + 1)); }
say_warn() { echo "  WARN $*"; warn=$((warn + 1)); }

echo "== Validando ${UNIT} =="

if ! command -v systemctl >/dev/null 2>&1; then
  echo "FAIL: systemctl no disponible. ¿Sistema sin systemd?"
  exit 1
fi

if [[ ! -f "${UNIT_PATH}" ]]; then
  say_fail "${UNIT_PATH} no existe. Instálalo primero."
  echo
  echo "RESULT: ${fail} fallo(s), ${warn} warning(s)."
  exit 1
fi
say_ok "${UNIT_PATH} existe"

# Syntax
if systemd-analyze verify "${UNIT_PATH}" 2>&1 | tee /tmp/sys07-verify.out | grep -q .; then
  say_fail "systemd-analyze verify reporta problemas:"
  sed 's/^/      /' /tmp/sys07-verify.out
else
  say_ok "systemd-analyze verify limpio"
fi

# Secciones mínimas
grep -q '^\[Unit\]'    "${UNIT_PATH}" && say_ok "sección [Unit] presente"    || say_fail "falta [Unit]"
grep -q '^\[Service\]' "${UNIT_PATH}" && say_ok "sección [Service] presente" || say_fail "falta [Service]"
grep -q '^\[Install\]' "${UNIT_PATH}" && say_ok "sección [Install] presente" || say_fail "falta [Install]"

# Directivas clave
grep -Eq '^Restart=on-failure\b'      "${UNIT_PATH}" && say_ok "Restart=on-failure"      || say_fail "falta Restart=on-failure"
grep -Eq '^WantedBy=multi-user.target' "${UNIT_PATH}" && say_ok "WantedBy=multi-user.target" || say_fail "falta WantedBy=multi-user.target"
grep -Eq '^ExecStart=/'               "${UNIT_PATH}" && say_ok "ExecStart con ruta absoluta" || say_fail "ExecStart debe ser ruta absoluta"

# User no-root
user_line="$(grep -E '^User=' "${UNIT_PATH}" | head -1 | cut -d= -f2 || true)"
if [[ -z "${user_line}" ]]; then
  say_fail "falta User= (no corras como root)"
elif [[ "${user_line}" == "root" ]]; then
  say_fail "User=root no permitido"
else
  say_ok "User=${user_line} (no-root)"
fi

# Al menos 3 opciones de hardening
hardening_count=0
for opt in PrivateTmp ProtectSystem ProtectHome NoNewPrivileges ProtectKernelTunables ProtectKernelModules ProtectControlGroups; do
  if grep -Eq "^${opt}=" "${UNIT_PATH}"; then
    hardening_count=$((hardening_count + 1))
  fi
done
if [[ "${hardening_count}" -ge 3 ]]; then
  say_ok "${hardening_count} opciones de hardening presentes"
else
  say_fail "solo ${hardening_count} opciones de hardening (mínimo 3)"
fi

# Estado runtime (si está instalado y habilitado)
enabled="$(systemctl is-enabled "${UNIT}" 2>/dev/null || echo "unknown")"
active="$(systemctl is-active "${UNIT}" 2>/dev/null || echo "unknown")"
[[ "${enabled}" == "enabled" ]] && say_ok "is-enabled=enabled" || say_fail "is-enabled=${enabled} (ejecuta: sudo systemctl enable --now ${UNIT})"
[[ "${active}"  == "active"  ]] && say_ok "is-active=active"   || say_fail "is-active=${active}"

# Logs presentes
log_lines="$(journalctl -u "${UNIT}" --no-pager -n 20 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${log_lines}" -ge 3 ]]; then
  say_ok "journalctl -u ${UNIT} tiene ${log_lines} líneas recientes"
else
  say_warn "pocas líneas de log (${log_lines}); espera un momento y reintenta"
fi

echo
if [[ "${fail}" -gt 0 ]]; then
  echo "RESULT: ${fail} fallo(s), ${warn} warning(s)."
  exit 1
fi
echo "OK: unit cumple requisitos (${warn} warning(s))."
exit 0
