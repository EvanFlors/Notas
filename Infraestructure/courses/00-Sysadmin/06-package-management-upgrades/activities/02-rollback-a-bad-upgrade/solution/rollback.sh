#!/usr/bin/env bash
# Solution — Reproducir y revertir una transacción con dnf history undo.
#
# Flujo:
#   1. Verifica entorno RHEL-family con dnf disponible.
#   2. Instala zsh (simula "paquete problemático").
#   3. Localiza la transacción recién creada (ID más alto que no sea Undo).
#   4. Muestra `dnf history info` para la transacción.
#   5. Ejecuta `dnf history undo` sobre ella.
#   6. Confirma que zsh ya no está instalado.
#
# Uso: sudo bash solution/rollback.sh
# Entorno: VM/contenedor Rocky 9 / Alma 9 / Fedora 41+ desechable.

set -euo pipefail

TARGET_PKG="zsh"

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: ejecuta como root (sudo bash $0)" >&2
    exit 2
  fi
}

require_rhel_family() {
  if [ ! -f /etc/os-release ]; then
    echo "ERROR: no se encontró /etc/os-release" >&2
    exit 2
  fi
  # shellcheck source=/dev/null
  . /etc/os-release
  case "${ID:-}${ID_LIKE:-}" in
    *rhel*|*fedora*|*rocky*|*almalinux*|*centos*) : ;;
    *)
      echo "ERROR: este laboratorio es para RHEL-family. Detectado: ${PRETTY_NAME:-?}" >&2
      exit 2
      ;;
  esac
}

require_dnf() {
  if command -v dnf5 >/dev/null 2>&1; then
    DNF=dnf5
  elif command -v dnf >/dev/null 2>&1; then
    DNF=dnf
  else
    echo "ERROR: ni dnf ni dnf5 disponibles" >&2
    exit 2
  fi
}

latest_install_tx_id() {
  # Devuelve el ID de la transacción más reciente cuyo Command Line contenga
  # "install <TARGET_PKG>" y no sea un "history undo".
  # Formato típico de `dnf history`:
  #   ID     | Command line                | Date and time    | Action(s) | Altered
  #   ----------------------------------------------------------------------
  #       3  | install -y zsh              | 2026-11-02 10:00 | Install   | 1
  "${DNF}" history 2>/dev/null \
    | awk -F'|' -v pkg="${TARGET_PKG}" '
        /^-+/ { next }
        /^ID/ || /ID[[:space:]]+\|/ { next }
        {
          id=$1; cmd=$2;
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", id);
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd);
          if (id ~ /^[0-9]+$/ && cmd ~ ("install.*" pkg) && cmd !~ /history undo/) {
            print id; exit
          }
        }'
}

main() {
  require_root
  require_rhel_family
  require_dnf

  echo "== Estado inicial del historial =="
  "${DNF}" history | head -5 || true

  echo
  echo "== Instalando ${TARGET_PKG} =="
  "${DNF}" install -y "${TARGET_PKG}"
  rpm -q "${TARGET_PKG}"

  echo
  echo "== Historial tras la instalación =="
  "${DNF}" history | head -5

  local tx_id
  tx_id=$(latest_install_tx_id || true)
  if [ -z "${tx_id:-}" ]; then
    echo "ERROR: no se pudo localizar la transacción de instalación de ${TARGET_PKG}" >&2
    exit 1
  fi
  echo "Transacción culpable: ID=${tx_id}"

  echo
  echo "== Detalles de la transacción ${tx_id} =="
  "${DNF}" history info "${tx_id}" || true

  echo
  echo "== Ejecutando undo de la transacción ${tx_id} =="
  "${DNF}" history undo -y "${tx_id}"

  echo
  echo "== Validación post-rollback =="
  if rpm -q "${TARGET_PKG}" >/dev/null 2>&1; then
    echo "ERROR: ${TARGET_PKG} sigue instalado tras el undo" >&2
    exit 1
  fi
  echo "OK: ${TARGET_PKG} ya no está instalado."

  echo
  echo "== Historial tras el undo (la última entrada debería ser el propio Undo) =="
  "${DNF}" history | head -5
}

main "$@"
