#!/usr/bin/env bash
# Validate: alta correcta del repo HashiCorp con patrón signed-by moderno.
# Exits 0 si OK, 1 si falla. Imprime checklist precisa.

set -o pipefail

fail=0
warn=0

ok()   { echo "  OK   $*"; }
bad()  { echo "  FAIL $*"; fail=$((fail+1)); }
warnm(){ echo "  WARN $*"; warn=$((warn+1)); }

echo "== Validando alta de repo HashiCorp =="

# 0. Pre-requisito: Debian/Ubuntu
if [ ! -f /etc/os-release ]; then
  bad "/etc/os-release no existe"
  exit 1
fi
# shellcheck source=/dev/null
. /etc/os-release
case "${ID:-}${ID_LIKE:-}" in
  *debian*|*ubuntu*) ok "distro Debian-family: ${PRETTY_NAME:-?}" ;;
  *) bad "este test solo aplica a Debian/Ubuntu. Detectado: ${PRETTY_NAME:-?}"; exit 1 ;;
esac

# 1. Directorio /etc/apt/keyrings/ existe y tiene permisos razonables
if [ -d /etc/apt/keyrings ]; then
  mode=$(stat -c '%a' /etc/apt/keyrings)
  owner=$(stat -c '%U:%G' /etc/apt/keyrings)
  if [ "${owner}" = "root:root" ] && [ "${mode}" = "755" ]; then
    ok "/etc/apt/keyrings existe (root:root 0755)"
  else
    warnm "/etc/apt/keyrings existe pero con permisos no canónicos (${owner} ${mode})"
  fi
else
  bad "/etc/apt/keyrings no existe"
fi

# 2. Keyring HashiCorp presente, binario, modo 0644 root:root
KEYRING="/etc/apt/keyrings/hashicorp-archive-keyring.gpg"
if [ -f "${KEYRING}" ]; then
  mode=$(stat -c '%a' "${KEYRING}")
  owner=$(stat -c '%U:%G' "${KEYRING}")
  if [ "${owner}" = "root:root" ] && [ "${mode}" = "644" ]; then
    ok "${KEYRING} (root:root 0644)"
  else
    bad "${KEYRING} con permisos no canónicos (${owner} ${mode}, esperado root:root 0644)"
  fi

  # Debe ser binario (dearmored), no ASCII armored.
  if head -c 10 "${KEYRING}" | grep -q "BEGIN PGP"; then
    bad "${KEYRING} está en ASCII armored (falta gpg --dearmor)"
  else
    ok "${KEYRING} está en formato binario (dearmored)"
  fi
else
  bad "falta ${KEYRING}"
fi

# 3. No debe haber clave de HashiCorp en el keyring GLOBAL (trusted.gpg.d) ni en /etc/apt/trusted.gpg
if ls /etc/apt/trusted.gpg.d/*ashicorp* 2>/dev/null | grep -q .; then
  bad "existe clave de HashiCorp en /etc/apt/trusted.gpg.d/ (patrón viejo, inseguro)"
else
  ok "no hay clave de HashiCorp en /etc/apt/trusted.gpg.d/"
fi

if [ -f /etc/apt/trusted.gpg ]; then
  if gpg --no-default-keyring --keyring /etc/apt/trusted.gpg --list-keys 2>/dev/null \
       | grep -qi hashicorp; then
    bad "existe clave de HashiCorp en /etc/apt/trusted.gpg (patrón viejo, inseguro)"
  else
    ok "no hay clave de HashiCorp en /etc/apt/trusted.gpg"
  fi
fi

# 4. Debe existir una fuente que apunte a hashicorp y use signed-by/Signed-By con la ruta correcta
found_source=""
for f in /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list; do
  [ -e "${f}" ] || continue
  if grep -q "apt.releases.hashicorp.com" "${f}" 2>/dev/null; then
    found_source="${f}"
    break
  fi
done

if [ -z "${found_source}" ]; then
  bad "no se encontró ningún .sources/.list que referencie apt.releases.hashicorp.com"
else
  ok "fuente encontrada: ${found_source}"
  if grep -Eq "([sS]igned-[bB]y[: =]+)${KEYRING}" "${found_source}"; then
    ok "fuente usa Signed-By=${KEYRING}"
  else
    bad "fuente ${found_source} no incluye Signed-By apuntando a ${KEYRING}"
  fi
fi

# 5. apt update sin errores de firma para este repo
tmp_out=$(mktemp)
if sudo apt-get update -o Dir::Etc::sourceparts="/etc/apt/sources.list.d" \
      -o Dir::Etc::sourcelist="/dev/null" \
      -o APT::Get::List-Cleanup="0" >"${tmp_out}" 2>&1; then
  if grep -q "hashicorp" "${tmp_out}"; then
    if grep -qE "NO_PUBKEY|not signed|BADSIG" "${tmp_out}"; then
      bad "apt update reporta problemas de firma para hashicorp"
      grep -E "NO_PUBKEY|not signed|BADSIG|hashicorp" "${tmp_out}" | sed 's/^/     /'
    else
      ok "apt update reconoce el repo hashicorp sin errores de firma"
    fi
  else
    warnm "apt update corrió pero no mencionó el repo hashicorp (¿sin red?)"
  fi
else
  warnm "apt update falló (posible falta de red); revisa manualmente"
  tail -5 "${tmp_out}" | sed 's/^/     /'
fi
rm -f "${tmp_out}"

echo
if [ "${fail}" -gt 0 ]; then
  echo "RESULT: ${fail} check(s) fallidos, ${warn} warning(s)."
  exit 1
fi
echo "OK: repo HashiCorp dado de alta con el patrón moderno (${warn} warning(s))."
exit 0
