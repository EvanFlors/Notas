#!/usr/bin/env bash
# Instala la solución de referencia completa. Requiere sudo.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARTER_DIR="$(cd "${SRC_DIR}/../starter" && pwd)"

UNIT="sys07-app.service"
BIN_SRC="${STARTER_DIR}/app.sh"
BIN_DEST="/usr/local/bin/sys07-app"
UNIT_SRC="${SRC_DIR}/app.service"
UNIT_DEST="/etc/systemd/system/${UNIT}"

if [[ $EUID -ne 0 ]]; then
  echo "Este script requiere root. Ejecuta: sudo bash $0" >&2
  exit 1
fi

if [[ ! -f "${BIN_SRC}" ]]; then
  echo "No se encuentra ${BIN_SRC}" >&2
  exit 1
fi

echo "==> Instalando binario en ${BIN_DEST}"
install -m 0755 "${BIN_SRC}" "${BIN_DEST}"

echo "==> Instalando unidad en ${UNIT_DEST}"
install -m 0644 "${UNIT_SRC}" "${UNIT_DEST}"

echo "==> Verificando syntax"
systemd-analyze verify "${UNIT_DEST}"

echo "==> daemon-reload"
systemctl daemon-reload

echo "==> enable --now ${UNIT}"
systemctl enable --now "${UNIT}"

sleep 2

echo "==> status"
systemctl --no-pager --full status "${UNIT}" || true

echo
echo "Listo. Siguiente:"
echo "  journalctl -u ${UNIT} -f"
echo "  bash ../tests/validate.sh"
