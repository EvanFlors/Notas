#!/usr/bin/env bash
# whiptail-menu.sh — Mismo menú con whiptail(1). Nota el idiom 3>&1 1>&2 2>&3.

set -euo pipefail

command -v whiptail >/dev/null || { echo "Falta 'whiptail' (paquete 'newt')." >&2; exit 2; }
[[ -t 1 ]] || { echo "stdout no es TTY; whiptail no es adecuado aquí." >&2; exit 2; }

# whiptail devuelve la respuesta por fd 3 (stderr por defecto); el truco redirige
# stderr al stdout original para capturar la respuesta en $choice.
choice=$(whiptail --title "demo-app" \
                  --menu "Elige una acción:" 12 50 3 \
                  1 "Mostrar estado" \
                  2 "Ver logs" \
                  3 "Reiniciar servicio" \
                  3>&1 1>&2 2>&3) || {
  clear
  echo "Cancelado por el usuario."
  exit 1
}
clear

case "$choice" in
  1) echo "[status]  demo-app: running (pid 12345)" ;;
  2) printf '%s\n' "[logs] info: request /health 200" "[logs] warn: slow query 812ms" ;;
  3) echo "[restart] reiniciando demo-app... OK" ;;
  *) echo "Opción inesperada: $choice" >&2; exit 1 ;;
esac
