#!/usr/bin/env bash
# Demo: wget con resume + reintentos + timeouts + exit code semantico.
# Reproducible: dado el mismo input, mismo output o fallo claro.
set -euo pipefail
IFS=$'\n\t'

DEST_DIR="${DEST_DIR:-/tmp/sys20-demo}"
URL="${URL:-https://ftp.gnu.org/gnu/hello/hello-2.12.tar.gz}"
OUT_NAME="$(basename "$URL")"
OUT_PATH="${DEST_DIR}/${OUT_NAME}"

# Exit codes semanticos (sysexits.h, BSD).
EX_UNAVAILABLE=69

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*" >&2; }

mkdir -p "$DEST_DIR"

log "INFO fetch URL=$URL out=$OUT_PATH"

# Nota: NO usamos --no-check-certificate. Si tu almacen de CAs esta roto,
# arreglalo (ca-certificates), no silencies la verificacion TLS.
if ! wget \
      --continue \
      --tries=5 \
      --waitretry=10 \
      --connect-timeout=10 \
      --read-timeout=30 \
      --retry-connrefused \
      --output-document="$OUT_PATH" \
      -- "$URL"; then
  log "ERROR fetch de $URL fallo tras agotar reintentos"
  exit "$EX_UNAVAILABLE"
fi

size="$(stat -c%s "$OUT_PATH" 2>/dev/null || stat -f%z "$OUT_PATH")"
log "OK   descargado $OUT_PATH size=${size}B"
