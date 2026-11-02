#!/usr/bin/env bash
# Starter: completalo segun el README.
# Uso:
#   ./pipeline.sh                                              # modo offline
#   ./pipeline.sh URL_ARTIFACT URL_SHA256 URL_ASC FINGERPRINT  # modo online
set -euo pipefail
IFS=$'\n\t'

EX_DATAERR=65
EX_UNAVAILABLE=69

WORK="${WORK:-/tmp/sys20-pipeline}"
mkdir -p "$WORK"

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*" >&2; }

# TODO: setear un GNUPGHOME temporal + trap EXIT para limpiar.

# TODO: funcion fetch() que invoque wget con las flags robustas de la actividad 1.

# TODO: modo offline (si $# == 0):
#   - generar artifact.bin
#   - generar SHA256SUMS
#   - generar clave efimera y firmar SHA256SUMS -> SHA256SUMS.asc
#   - verificar sha256sum --check --strict
#   - verificar gpg --verify SHA256SUMS.asc SHA256SUMS
#   - exit 0

# TODO: modo online (si $# == 4):
#   - fetch de los 3 URLs
#   - verificar sha256sum --check --strict
#   - verificar gpg --verify ; capturar fingerprint; comparar con $4
#   - abortar con EX_UNAVAILABLE si firma invalida o fingerprint no coincide

# TODO: si $# no es 0 ni 4 -> exit 2.

log "ERROR starter sin completar"
exit 2
