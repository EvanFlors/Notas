#!/usr/bin/env bash
# Solution — Añadir repo APT de HashiCorp con firma GPG verificada.
# Patrón moderno: /etc/apt/keyrings/ + signed-by=.
#
# Diseño: la verificación del fingerprint es MANUAL por diseño.
# El script muestra el fingerprint y exige confirmación explícita; no
# continúa sola. Automatizar la verificación derrotaría el propósito.
#
# Uso: sudo bash solution/add-repo.sh
# Entorno: VM/contenedor Debian 12 o Ubuntu 22.04+ desechable.

set -euo pipefail

KEY_URL="https://apt.releases.hashicorp.com/gpg"
REPO_URL="https://apt.releases.hashicorp.com"
KEYRING_PATH="/etc/apt/keyrings/hashicorp-archive-keyring.gpg"
SOURCES_PATH="/etc/apt/sources.list.d/hashicorp.sources"
# Fingerprint esperado publicado por HashiCorp en
# https://www.hashicorp.com/trust/security
# Si HashiCorp lo rota, actualiza esta constante tras verificarlo tú.
EXPECTED_FPR="798AEC654E5C15428C8E42EEAA16FCBCA621E701"

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: ejecuta este script como root (sudo bash $0)" >&2
    exit 2
  fi
}

require_debian_family() {
  if [ ! -f /etc/os-release ]; then
    echo "ERROR: no se encontró /etc/os-release" >&2
    exit 2
  fi
  . /etc/os-release
  case "${ID:-}${ID_LIKE:-}" in
    *debian*|*ubuntu*) : ;;
    *)
      echo "ERROR: este laboratorio es para Debian/Ubuntu. Detectado: ${PRETTY_NAME:-?}" >&2
      exit 2
      ;;
  esac
  if [ -z "${VERSION_CODENAME:-}" ]; then
    echo "ERROR: no se detectó VERSION_CODENAME en /etc/os-release" >&2
    exit 2
  fi
}

require_tools() {
  local tool
  for tool in curl gpg apt install tee chmod chown mktemp; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      echo "ERROR: falta la herramienta '${tool}'" >&2
      exit 2
    fi
  done
}

main() {
  require_root
  require_debian_family
  require_tools

  . /etc/os-release
  local codename="${VERSION_CODENAME}"
  echo "== Alta repo HashiCorp en ${PRETTY_NAME} (codename=${codename}) =="

  # 1. Directorio canónico de keyrings
  install -d -m 0755 -o root -g root /etc/apt/keyrings

  # 2. Descargar la clave a un temporal
  local tmp_key
  tmp_key=$(mktemp --suffix=.asc)
  # shellcheck disable=SC2064
  trap "rm -f '${tmp_key}'" EXIT
  curl -fsSL "${KEY_URL}" -o "${tmp_key}"

  # 3. Mostrar fingerprint y pedir confirmación MANUAL
  echo
  echo "=== Fingerprint de la clave descargada ==="
  gpg --show-keys --with-fingerprint "${tmp_key}"
  echo
  echo "Fingerprint ESPERADO (publicado por HashiCorp):"
  echo "    ${EXPECTED_FPR}"
  echo
  echo "Verifica manualmente contra: https://www.hashicorp.com/trust/security"

  # Comprobación automática contra la constante conocida
  local actual_fpr
  actual_fpr=$(gpg --show-keys --with-colons --with-fingerprint "${tmp_key}" \
    | awk -F: '/^fpr:/ {print $10; exit}')
  if [ "${actual_fpr}" != "${EXPECTED_FPR}" ]; then
    echo "ERROR: el fingerprint descargado (${actual_fpr}) NO coincide con el esperado." >&2
    echo "       Posible compromiso o rotación de clave. ABORTANDO." >&2
    exit 1
  fi
  echo "OK: fingerprint descargado coincide con el esperado."

  # Confirmación humana explícita (no auto-pilot)
  if [ "${CONFIRM:-}" != "yes" ]; then
    read -r -p "Has verificado también visualmente contra la web oficial? (yes/NO) " answer
    if [ "${answer}" != "yes" ]; then
      echo "Abortado por el usuario. No se instaló ninguna clave." >&2
      exit 1
    fi
  fi

  # 4. Dearmor y mover a su ubicación final con permisos canónicos
  gpg --dearmor -o "${KEYRING_PATH}" "${tmp_key}"
  chown root:root "${KEYRING_PATH}"
  chmod 0644 "${KEYRING_PATH}"

  # 5. Crear el .sources en formato DEB822
  tee "${SOURCES_PATH}" >/dev/null <<EOF
Types: deb
URIs: ${REPO_URL}
Suites: ${codename}
Components: main
Signed-By: ${KEYRING_PATH}
EOF
  chmod 0644 "${SOURCES_PATH}"

  # 6. Refrescar índices
  apt update

  echo
  echo "OK: repo HashiCorp añadido correctamente."
  echo "    Keyring:  ${KEYRING_PATH}"
  echo "    Sources:  ${SOURCES_PATH}"
}

main "$@"
