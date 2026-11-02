#!/usr/bin/env bash
# sys-12-01 — Validador de la ruleset del alumno.
# No aplica nada: valida sintaxis y contenido.
#
# USO:
#   bash tests/validate.sh <ruta-a-nftables.conf>
#
# Exit code 0 si todo pasa, 1 si cualquier check requerido falla.

set -o pipefail

CONF="${1:-}"
if [[ -z "$CONF" ]]; then
    echo "USO: bash tests/validate.sh <ruta-a-nftables.conf>" >&2
    exit 1
fi

if [[ ! -f "$CONF" ]]; then
    echo "FAIL: no existe el fichero $CONF" >&2
    exit 1
fi

fail=0

check() {
    local label="$1"
    local pattern="$2"
    if grep -Eq "$pattern" "$CONF"; then
        echo "  OK   $label"
    else
        echo "  FAIL $label (no se encontró patrón: $pattern)"
        fail=$((fail+1))
    fi
}

echo "== Validando $CONF =="

# 1. Sintaxis. Si no hay 'nft', avisa pero continúa con los checks de contenido.
if command -v nft >/dev/null 2>&1; then
    if nft -c -f "$CONF" >/tmp/nft-check.err 2>&1; then
        echo "  OK   sintaxis nftables válida (nft -c -f)"
    else
        echo "  FAIL sintaxis nftables inválida:"
        sed 's/^/      /' /tmp/nft-check.err
        fail=$((fail+1))
    fi
else
    echo "  WARN 'nft' no instalado; se omite comprobación de sintaxis."
fi

# 2. Contenido.
check "política drop en input"      'chain[[:space:]]+input[[:space:]]*\{[^}]*policy[[:space:]]+drop'
check "política drop en forward"    'chain[[:space:]]+forward[[:space:]]*\{[^}]*policy[[:space:]]+drop'
check "loopback aceptado"           'iif[[:space:]]+"?lo"?[[:space:]]+accept'
check "conntrack established,related" 'ct[[:space:]]+state[[:space:]]+established,related[[:space:]]+accept'
check "conntrack invalid drop"      'ct[[:space:]]+state[[:space:]]+invalid[[:space:]]+drop'
check "HTTPS 443 aceptado"          'tcp[[:space:]]+dport[[:space:]]+(443|\{[^}]*\<443\>[^}]*\})[[:space:]].*accept'

# SSH restringido a 10.0.0.0/24. Aceptamos orden de match en cualquier orden.
if grep -Eq 'tcp[[:space:]]+dport[[:space:]]+22[[:space:]]+ip[[:space:]]+saddr[[:space:]]+10\.0\.0\.0/24[[:space:]]+accept' "$CONF" \
   || grep -Eq 'ip[[:space:]]+saddr[[:space:]]+10\.0\.0\.0/24[[:space:]]+tcp[[:space:]]+dport[[:space:]]+22[[:space:]]+accept' "$CONF"; then
    echo "  OK   SSH 22 restringido a 10.0.0.0/24"
else
    echo "  FAIL SSH 22 no está restringido a 10.0.0.0/24"
    fail=$((fail+1))
fi

echo
if [[ $fail -gt 0 ]]; then
    echo "RESULT: $fail check(s) fallaron."
    exit 1
fi
echo "RESULT: OK"
exit 0
