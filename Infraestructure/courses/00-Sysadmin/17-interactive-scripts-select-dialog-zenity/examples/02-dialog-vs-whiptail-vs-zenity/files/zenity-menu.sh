#!/usr/bin/env bash
# zenity-menu.sh — Mismo menú con zenity(1), GUI GTK. Requiere sesión gráfica.

set -euo pipefail

command -v zenity >/dev/null || { echo "Falta 'zenity'." >&2; exit 2; }
if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  echo "No hay sesión gráfica (DISPLAY/WAYLAND_DISPLAY vacíos). zenity no funcionará." >&2
  exit 2
fi

choice=$(zenity --list \
                --title="demo-app" \
                --text="Elige una acción:" \
                --column="ID" --column="Acción" \
                --hide-header \
                1 "Mostrar estado" \
                2 "Ver logs" \
                3 "Reiniciar servicio") || {
  echo "Cancelado por el usuario."
  exit 1
}

case "$choice" in
  1) zenity --info --text="demo-app: running (pid 12345)" ;;
  2) zenity --info --text="[logs]\ninfo: request /health 200\nwarn: slow query 812ms" ;;
  3) zenity --info --text="Reiniciando demo-app... OK" ;;
  *) echo "Opción inesperada: $choice" >&2; exit 1 ;;
esac
