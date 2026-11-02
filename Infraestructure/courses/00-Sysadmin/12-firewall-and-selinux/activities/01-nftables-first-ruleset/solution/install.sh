#!/usr/bin/env bash
# sys-12-01 — Instalación segura de la ruleset de referencia.
#
# Patrón: validar sintaxis, programar rollback por si pierdes SSH,
# aplicar, y cancelar rollback manualmente tras verificar.
#
# USO:
#   sudo CONFIRM=1 bash install.sh [ruta-al-conf]
#
# Sin CONFIRM=1 el script no toca el sistema: sólo valida sintaxis.

set -euo pipefail

CONF="${1:-$(dirname "$0")/nftables.conf}"

if [[ ! -f "$CONF" ]]; then
    echo "ERROR: no existe $CONF" >&2
    exit 1
fi

if ! command -v nft >/dev/null 2>&1; then
    echo "ERROR: 'nft' no está instalado." >&2
    exit 1
fi

echo "== 1. Validando sintaxis =="
nft -c -f "$CONF"
echo "OK: sintaxis válida."

if [[ "${CONFIRM:-}" != "1" ]]; then
    cat <<'EOF'

Modo seguro: no se ha aplicado nada.
Para aplicar realmente (en una VM desechable y como root), re-ejecuta con:

    sudo CONFIRM=1 bash install.sh [ruta-al-conf]

Esto hará: aplicar la ruleset, programar un rollback automático a los 2
minutos vía 'at', y pedirte confirmación interactiva para cancelar el
rollback una vez compruebes que SSH sigue vivo.
EOF
    exit 0
fi

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: con CONFIRM=1 debes ejecutar como root (usa sudo)." >&2
    exit 1
fi

echo "== 2. Programando rollback a los 2 minutos =="
if ! command -v at >/dev/null 2>&1; then
    echo "AVISO: 'at' no está instalado. No se programará rollback." >&2
    echo "        Instálalo con: dnf install at   o   apt install at" >&2
    JOB_ID=""
else
    at now + 2 minutes <<'AT_EOF' 2>/tmp/at.err
nft flush ruleset
AT_EOF
    JOB_ID="$(awk 'END{print $2}' /tmp/at.err)"
    echo "Rollback programado (job $JOB_ID)."
fi

echo "== 3. Aplicando ruleset =="
nft -f "$CONF"
echo "OK: ruleset aplicada."

echo
echo "Verifica desde OTRA sesión que SSH sigue funcionando."
echo "Cuando lo confirmes, pulsa Enter para cancelar el rollback."
read -r _

if [[ -n "$JOB_ID" ]]; then
    atrm "$JOB_ID" && echo "Rollback cancelado."
fi

echo "== 4. Ruleset efectiva =="
nft list ruleset
