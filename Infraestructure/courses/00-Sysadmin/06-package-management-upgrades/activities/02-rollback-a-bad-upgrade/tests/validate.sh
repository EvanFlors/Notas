#!/usr/bin/env bash
# Validate: el laboratorio de rollback se completó.
# Exits 0 si OK, 1 si falla.

set -o pipefail

TARGET_PKG="zsh"
fail=0
warn=0

ok()   { echo "  OK   $*"; }
bad()  { echo "  FAIL $*"; fail=$((fail+1)); }
warnm(){ echo "  WARN $*"; warn=$((warn+1)); }

echo "== Validando rollback con dnf history undo =="

# 0. Pre-requisito: RHEL-family
if [ ! -f /etc/os-release ]; then
  bad "/etc/os-release no existe"
  exit 1
fi
# shellcheck source=/dev/null
. /etc/os-release
case "${ID:-}${ID_LIKE:-}" in
  *rhel*|*fedora*|*rocky*|*almalinux*|*centos*)
    ok "distro RHEL-family: ${PRETTY_NAME:-?}"
    ;;
  *)
    bad "este test solo aplica a RHEL-family. Detectado: ${PRETTY_NAME:-?}"
    exit 1
    ;;
esac

# 1. dnf disponible
if command -v dnf5 >/dev/null 2>&1; then
  DNF=dnf5
  ok "dnf5 disponible"
elif command -v dnf >/dev/null 2>&1; then
  DNF=dnf
  ok "dnf disponible"
else
  bad "ni dnf ni dnf5 están instalados"
  exit 1
fi

# 2. zsh NO debe estar instalado al final (el undo lo removió)
if rpm -q "${TARGET_PKG}" >/dev/null 2>&1; then
  bad "${TARGET_PKG} sigue instalado — el undo no se ejecutó o no sobre la transacción correcta"
else
  ok "${TARGET_PKG} no está instalado (el undo revirtió la instalación)"
fi

# 3. Debe existir una transacción de instalación de zsh en el historial
history_out=$(sudo "${DNF}" history 2>/dev/null || true)
if echo "${history_out}" | grep -Eq "install.*${TARGET_PKG}"; then
  ok "el historial registra la instalación original de ${TARGET_PKG}"
else
  warnm "no se detecta la instalación original de ${TARGET_PKG} en el historial (¿historial purgado?)"
fi

# 4. Debe existir una entrada posterior de tipo "undo" o acción Removed sobre esa misma transacción
# dnf5 lo muestra como "history undo", dnf4 similar.
if echo "${history_out}" | grep -Eiq "(history undo|undo)"; then
  ok "el historial contiene al menos una entrada de 'undo'"
else
  bad "no se encuentra ninguna entrada de 'undo' en el historial"
fi

echo
if [ "${fail}" -gt 0 ]; then
  echo "RESULT: ${fail} check(s) fallidos, ${warn} warning(s)."
  exit 1
fi
echo "OK: rollback completado correctamente (${warn} warning(s))."
exit 0
