#!/usr/bin/env bash
# runbook.sh — Starter. Completa los TODO para pasar tests/validate.sh.
#
# Objetivo: menú interactivo con `select` que operará un servicio ficticio
# llamado "demo-app". 4 opciones: estado, logs, reiniciar (con confirmación),
# salir. Sin dependencias externas.

set -euo pipefail

SERVICE="demo-app"

do_status() {
  # TODO: imprime una línea que incluya la palabra "status" y el nombre del servicio.
  :
}

do_logs() {
  # TODO: imprime al menos 3 líneas de "logs" simulados.
  :
}

do_restart() {
  # TODO:
  # 1. Pregunta: read -r -n 1 -p "¿Confirmas reinicio (y/N)? " ans; echo
  # 2. Si ans es 'y' o 'Y' imprime "[restart] reiniciando $SERVICE... OK"
  # 3. En caso contrario imprime "[restart] cancelado" y RETORNA (no salgas del script).
  :
}

PS3="$SERVICE> Elige una opción (número): "
options=("Mostrar estado" "Ver últimos logs" "Reiniciar servicio" "Salir")

echo "== Runbook interactivo de $SERVICE =="

# TODO: implementa el bloque `select ... do ... done` que llama a las funciones
# anteriores según $REPLY (1..4). En la opción 4 usa `break`. Para $REPLY vacío
# (Enter en vacío) no hagas nada; para cualquier otro valor imprime "Opción no
# reconocida: '$REPLY'. Usa 1-4.".
