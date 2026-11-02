#!/usr/bin/env bash
# Solucion: descarga robusta con resume, timeouts, reintentos.
# Uso: ./fetch.sh <URL> <OUT_PATH>
set -euo pipefail
IFS=$'\n\t'

EX_USAGE=2
EX_UNAVAILABLE=69

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*" >&2; }

if [[ $# -ne 2 ]]; then
  log "ERROR uso: $0 <URL> <OUT_PATH>"
  exit "$EX_USAGE"
fi

URL="$1"
OUT="$2"

mkdir -p -- "$(dirname -- "$OUT")"

log "INFO fetch URL=$URL out=$OUT"

# TLS verification NUNCA se silencia aqui.
if ! wget \
      --continue \
      --tries=5 \
      --waitretry=10 \
      --connect-timeout=10 \
      --read-timeout=30 \
      --retry-connrefused \
      --output-document="$OUT" \
      -- "$URL"; then
  log "ERROR fetch de $URL fallo tras agotar reintentos (out=$OUT)"
  exit "$EX_UNAVAILABLE"
fi

size="$(stat -c%s "$OUT" 2>/dev/null || stat -f%z "$OUT")"
log "OK   descargado $OUT size=${size}B"
