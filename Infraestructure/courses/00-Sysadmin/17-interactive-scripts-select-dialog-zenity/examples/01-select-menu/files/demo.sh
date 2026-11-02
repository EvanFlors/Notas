#!/usr/bin/env bash
# demo.sh — Runbook demostrativo con el builtin `select`.
# Opera un servicio ficticio llamado "demo-app" sin dependencias externas.

set -euo pipefail

SERVICE="demo-app"

do_status()  { echo "[status]  $SERVICE: running (pid 12345, uptime 3h)"; }
do_logs()    { echo "[logs]    (últimas 3 líneas simuladas)"
               printf '  %s\n' "info: request /health 200" \
                               "warn: slow query 812ms" \
                               "info: gc pause 4ms"; }
do_restart() { echo "[restart] reiniciando $SERVICE... OK"; }

PS3="demo-app> Elige una opción (número): "
options=("Mostrar estado" "Ver últimos logs" "Reiniciar servicio" "Salir")

echo "== Runbook interactivo de $SERVICE =="
select opt in "${options[@]}"; do
  case "${REPLY:-}" in
    1) do_status ;;
    2) do_logs ;;
    3) do_restart ;;
    4) echo "Saliendo."; break ;;
    "") : ;;  # Enter en vacío → `select` repinta el menú
    *) echo "Opción no reconocida: '${REPLY}'. Usa 1-4." ;;
  esac
done
