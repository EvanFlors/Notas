#!/usr/bin/env bash
# Instala backup.timer + backup.service en /etc/systemd/system/.
# Idempotente: re-ejecutar no causa daño.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="/etc/systemd/system"
UNIT_TIMER="backup.timer"
UNIT_SERVICE="backup.service"

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: este script debe correr como root (sudo bash install.sh)." >&2
    exit 1
fi

for unit in "${UNIT_SERVICE}" "${UNIT_TIMER}"; do
    src="${HERE}/${unit}"
    if [[ ! -f "${src}" ]]; then
        echo "ERROR: no se encontró ${src}" >&2
        exit 1
    fi
    install -m 0644 -o root -g root "${src}" "${DEST}/${unit}"
    echo "  OK   instalado ${DEST}/${unit}"
done

systemctl daemon-reload
systemctl enable --now "${UNIT_TIMER}"

echo
systemctl list-timers "${UNIT_TIMER}" --no-pager || true
echo
echo "OK: backup.timer habilitado. Ver logs con: journalctl -u ${UNIT_SERVICE}"
