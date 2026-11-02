#!/usr/bin/env bash
# runbook.sh — Solución de referencia.
# Runbook interactivo para "demo-app" con el builtin `select`.

set -euo pipefail

SERVICE="demo-app"

do_status() {
  echo "[status]  $SERVICE: running (pid 12345, uptime 3h)"
}

do_logs() {
  printf '  %s\n' \
    "[logs] info: request /health 200" \
    "[logs] warn: slow query 812ms" \
    "[logs] info: gc pause 4ms"
}

do_restart() {
  local ans=""
  read -r -n 1 -p "¿Confirmas reinicio (y/N)? " ans
  echo
  if [[ "$ans" =~ ^[yY]$ ]]; then
    echo "[restart] reiniciando $SERVICE... OK"
  else
    echo "[restart] cancelado"
    return 0
  fi
}

PS3="$SERVICE> Elige una opción (número): "
options=("Mostrar estado" "Ver últimos logs" "Reiniciar servicio" "Salir")

echo "== Runbook interactivo de $SERVICE =="
select opt in "${options[@]}"; do
  case "${REPLY:-}" in
    1) do_status ;;
    2) do_logs ;;
    3) do_restart ;;
    4) echo "Saliendo."; break ;;
    "") : ;;
    *) echo "Opción no reconocida: '${REPLY}'. Usa 1-4." ;;
  esac
done
