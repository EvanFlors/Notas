#!/usr/bin/env bash
# Instala, habilita y arranca hello.service. Requiere sudo.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT="hello.service"
DEST="/etc/systemd/system/${UNIT}"

if [[ $EUID -ne 0 ]]; then
  echo "Este script requiere root. Ejecuta: sudo bash $0" >&2
  exit 1
fi

echo "==> Copiando ${UNIT} a ${DEST}"
install -m 0644 "${SRC_DIR}/${UNIT}" "${DEST}"

echo "==> daemon-reload"
systemctl daemon-reload

echo "==> enable --now ${UNIT}"
systemctl enable --now "${UNIT}"

echo "==> status (resumen)"
systemctl --no-pager --full status "${UNIT}" || true

cat <<'EOF'

Siguiente paso:
  journalctl -u hello.service -f

Para limpiar:
  sudo systemctl disable --now hello.service
  sudo rm /etc/systemd/system/hello.service
  sudo systemctl daemon-reload
EOF
