#!/usr/bin/env bash
# Demo: pipeline minimo de verificacion por checksum (y GPG si esta disponible).
# Lab offline: generamos artefacto + checksum + (opcional) firma localmente.
set -euo pipefail
IFS=$'\n\t'

WORK="${WORK:-/tmp/sys20-verify}"
ART="${WORK}/artifact.bin"
SUMS="${WORK}/SHA256SUMS"
ASC="${WORK}/SHA256SUMS.asc"

EX_DATAERR=65
EX_UNAVAILABLE=69

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*" >&2; }

mkdir -p "$WORK"

# 1. "Descargar" un artefacto (aqui lo generamos localmente para ser offline).
if [[ ! -f "$ART" ]]; then
  log "INFO generando artefacto de muestra"
  printf 'contenido reproducible\n' > "$ART"
fi

# 2. Generar SHA256SUMS si no existe (en la vida real vendria del publisher).
if [[ ! -f "$SUMS" ]]; then
  log "INFO publicando SHA256SUMS"
  ( cd "$WORK" && sha256sum -- "$(basename "$ART")" > "$(basename "$SUMS")" )
fi

# 3. Verificar checksum (modo auditable).
log "INFO verificando SHA256 via --check"
if ( cd "$WORK" && sha256sum --check --strict -- "$(basename "$SUMS")" ); then
  log "OK   sha256 verificado"
else
  log "ERROR sha256sum --check fallo"
  exit "$EX_DATAERR"
fi

# 4. Verificacion GPG opcional (solo si gpg esta disponible y hay una clave).
if command -v gpg >/dev/null 2>&1; then
  if [[ ! -f "$ASC" ]]; then
    log "INFO gpg disponible; generando firma de demo (clave efimera)"
    # Clave efimera para demo; nunca uses esto en produccion.
    GNUPGHOME="$(mktemp -d)"
    export GNUPGHOME
    trap 'rm -rf "$GNUPGHOME"' EXIT
    gpg --batch --quick-generate-key \
        --passphrase '' --pinentry-mode loopback \
        'sys20-demo <demo@example.invalid>' default default never >/dev/null 2>&1
    gpg --batch --yes --output "$ASC" --detach-sign --armor "$SUMS"
  fi

  log "INFO verificando firma GPG de SHA256SUMS"
  if gpg --verify "$ASC" "$SUMS" 2>&1 | tee -a /dev/stderr | grep -q 'Good signature'; then
    log "OK   firma GPG verificada (fingerprint deberia chequearse aparte)"
  else
    log "ERROR firma GPG invalida o ausente"
    exit "$EX_UNAVAILABLE"
  fi
else
  log "WARN gpg no instalado; omitiendo verificacion de firma"
fi

log "OK   artefacto $ART listo para usar"
