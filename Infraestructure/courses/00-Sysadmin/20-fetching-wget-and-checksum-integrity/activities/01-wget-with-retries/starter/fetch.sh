#!/usr/bin/env bash
# Starter: completalo segun el README.
# Uso: ./fetch.sh <URL> <OUT_PATH>
set -euo pipefail
IFS=$'\n\t'

EX_USAGE=2
EX_UNAVAILABLE=69

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*" >&2; }

# TODO 1: validar que $# == 2, si no exit $EX_USAGE con mensaje a stderr.

# TODO 2: asignar URL y OUT a $1 y $2.

# TODO 3: crear el directorio padre de OUT si no existe.

# TODO 4: invocar wget con las flags del README y, si falla, exit $EX_UNAVAILABLE.
#   PROHIBIDO: --no-check-certificate, -k, --insecure.

# TODO 5: loggear el tamaño final.

log "ERROR starter sin completar"
exit "$EX_USAGE"
