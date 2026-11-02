#!/usr/bin/env bash
# Solucion: pipeline fetch + sha256 + gpg con exit codes semanticos.
# Modos:
#   ./pipeline.sh                                              # offline (demo)
#   ./pipeline.sh URL_ARTIFACT URL_SHA256 URL_ASC FINGERPRINT  # online
set -euo pipefail
IFS=$'\n\t'

EX_USAGE=2
EX_DATAERR=65
EX_UNAVAILABLE=69

WORK="${WORK:-/tmp/sys20-pipeline}"
mkdir -p "$WORK"

GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
cleanup() { rm -rf -- "$GNUPGHOME"; }
trap cleanup EXIT

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*" >&2; }

fetch() {
  local url="$1" out="$2"
  mkdir -p -- "$(dirname -- "$out")"
  log "INFO fetch $url -> $out"
  if ! wget \
        --continue \
        --tries=5 \
        --waitretry=10 \
        --connect-timeout=10 \
        --read-timeout=30 \
        --retry-connrefused \
        --output-document="$out" \
        -- "$url"; then
    log "ERROR fetch de $url fallo"
    exit "$EX_UNAVAILABLE"
  fi
}

verify_sha256() {
  local dir="$1" sums="$2"
  log "INFO verificando sha256 (--check --strict) sobre $sums"
  if ( cd "$dir" && sha256sum --check --strict -- "$sums" ); then
    log "OK   sha256 verificado"
  else
    log "ERROR sha256sum --check fallo"
    exit "$EX_DATAERR"
  fi
}

verify_gpg() {
  local sig="$1" data="$2" expected_fpr="${3:-}"
  log "INFO verificando firma GPG $sig sobre $data"
  local status_file
  status_file="$(mktemp)"
  if ! gpg --status-file "$status_file" --verify "$sig" "$data" 2>&1 | sed 's/^/    gpg: /' >&2; then
    log "ERROR firma GPG invalida"
    rm -f -- "$status_file"
    exit "$EX_UNAVAILABLE"
  fi
  local fpr
  fpr="$(awk '/^\[GNUPG:\] VALIDSIG /{print $3}' "$status_file" | head -n1)"
  rm -f -- "$status_file"
  log "OK   firma GPG valida fingerprint=$fpr"
  if [[ -n "$expected_fpr" ]]; then
    local want
    want="$(printf '%s' "$expected_fpr" | tr -d ' \t' | tr '[:lower:]' '[:upper:]')"
    local got
    got="$(printf '%s' "$fpr" | tr -d ' \t' | tr '[:lower:]' '[:upper:]')"
    if [[ "$want" != "$got" ]]; then
      log "ERROR fingerprint mismatch esperado=$want obtenido=$got"
      exit "$EX_UNAVAILABLE"
    fi
    log "OK   fingerprint coincide con el esperado"
  fi
}

offline_mode() {
  log "INFO modo offline (sin red)"
  local art="$WORK/artifact.bin"
  local sums="SHA256SUMS"
  printf 'contenido reproducible\n' > "$art"

  ( cd "$WORK" && sha256sum -- "$(basename "$art")" > "$sums" )

  gpg --batch --quick-generate-key \
      --passphrase '' --pinentry-mode loopback \
      'sys20-pipeline <demo@example.invalid>' default default never >/dev/null 2>&1

  gpg --batch --yes --output "$WORK/${sums}.asc" --detach-sign --armor "$WORK/${sums}"

  verify_sha256 "$WORK" "$sums"
  verify_gpg "$WORK/${sums}.asc" "$WORK/${sums}"

  log "OK   pipeline offline completo; artefacto listo en $art"
}

online_mode() {
  local url_art="$1" url_sha="$2" url_asc="$3" fpr="$4"
  log "INFO modo online"
  local art_name sha_name asc_name
  art_name="$(basename -- "$url_art")"
  sha_name="$(basename -- "$url_sha")"
  asc_name="$(basename -- "$url_asc")"

  fetch "$url_art" "$WORK/$art_name"
  fetch "$url_sha" "$WORK/$sha_name"
  fetch "$url_asc" "$WORK/$asc_name"

  verify_sha256 "$WORK" "$sha_name"

  # Si el .asc firma al artefacto directamente:
  if gpg --list-packets "$WORK/$asc_name" 2>/dev/null | grep -q 'signature packet'; then
    verify_gpg "$WORK/$asc_name" "$WORK/$art_name" "$fpr"
  else
    log "ERROR .asc no es una firma GPG reconocible"
    exit "$EX_UNAVAILABLE"
  fi

  log "OK   pipeline online completo; artefacto listo en $WORK/$art_name"
}

case $# in
  0) offline_mode ;;
  4) online_mode "$1" "$2" "$3" "$4" ;;
  *)
    log "ERROR uso: $0  |  $0 URL_ART URL_SHA URL_ASC FINGERPRINT"
    exit "$EX_USAGE"
    ;;
esac
