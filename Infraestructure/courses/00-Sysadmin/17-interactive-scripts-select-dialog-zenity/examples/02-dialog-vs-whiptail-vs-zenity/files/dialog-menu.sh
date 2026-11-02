#!/usr/bin/env bash
# dialog-menu.sh — Menú de 3 opciones usando dialog(1).

set -euo pipefail

command -v dialog >/dev/null || { echo "Falta 'dialog'. Instala el paquete." >&2; exit 2; }
[[ -t 1 ]] || { echo "stdout no es TTY; dialog no es adecuado aquí." >&2; exit 2; }

if ! choice=$(dialog --stdout \
                     --title "demo-app" \
                     --menu "Elige una acción:" 12 50 3 \
                     1 "Mostrar estado" \
                     2 "Ver logs" \
                     3 "Reiniciar servicio"); then
  clear
  echo "Cancelado por el usuario."
  exit 1
fi
clear

case "$choice" in
  1) echo "[status]  demo-app: running (pid 12345)" ;;
  2) printf '%s\n' "[logs] info: request /health 200" "[logs] warn: slow query 812ms" ;;
  3) echo "[restart] reiniciando demo-app... OK" ;;
  *) echo "Opción inesperada: $choice" >&2; exit 1 ;;
esac
