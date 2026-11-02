#!/usr/bin/env bash
# sys-12-02 — Validador.
#
# Comprueba el estado final deseado:
#  - SELinux en Enforcing
#  - nginx activo
#  - nginx escuchando en PORT (default 8443)
#  - semanage port -l muestra PORT dentro de http_port_t
#  - sin AVCs recientes de name_bind sobre PORT
#
# USO:
#   bash tests/validate.sh                # usa PORT=8443
#   PORT=9443 bash tests/validate.sh

set -o pipefail

PORT="${PORT:-8443}"

fail=0

ok()   { echo "  OK   $*"; }
bad()  { echo "  FAIL $*"; fail=$((fail+1)); }
warn() { echo "  WARN $*"; }

echo "== Validando (PORT=$PORT) =="

# 1. SELinux Enforcing
if command -v getenforce >/dev/null 2>&1; then
    mode="$(getenforce)"
    if [[ "$mode" == "Enforcing" ]]; then
        ok "SELinux en Enforcing"
    else
        bad "SELinux en '$mode' (se esperaba Enforcing)"
    fi
else
    warn "getenforce no disponible (¿sistema sin SELinux?)"
fi

# 2. nginx activo
if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet nginx; then
        ok "nginx activo"
    else
        bad "nginx no está activo"
    fi
else
    warn "systemctl no disponible"
fi

# 3. nginx escuchando en PORT
if command -v ss >/dev/null 2>&1; then
    if ss -ltnp 2>/dev/null | grep -E ":$PORT\\b" | grep -q nginx; then
        ok "nginx escuchando en $PORT"
    else
        bad "nginx no está escuchando en $PORT"
    fi
else
    warn "ss no disponible; omitiendo check de listen"
fi

# 4. PORT en http_port_t
if command -v semanage >/dev/null 2>&1; then
    if sudo -n semanage port -l 2>/dev/null | grep -E "^http_port_t[[:space:]]+tcp[[:space:]].*\\<$PORT\\>" >/dev/null; then
        ok "puerto $PORT etiquetado como http_port_t"
    else
        # Reintento sin sudo por si corremos como root
        if semanage port -l 2>/dev/null | grep -E "^http_port_t[[:space:]]+tcp[[:space:]].*\\<$PORT\\>" >/dev/null; then
            ok "puerto $PORT etiquetado como http_port_t"
        else
            bad "puerto $PORT NO está en http_port_t (usa: semanage port -a -t http_port_t -p tcp $PORT)"
        fi
    fi
else
    warn "semanage no disponible; instala policycoreutils-python-utils"
fi

# 5. Sin AVCs recientes
if command -v ausearch >/dev/null 2>&1; then
    if sudo -n ausearch -m AVC -ts recent 2>/dev/null | grep -E "name_bind" | grep -q "$PORT"; then
        bad "siguen apareciendo AVCs name_bind sobre $PORT en los últimos minutos"
    else
        ok "sin AVCs name_bind recientes sobre $PORT"
    fi
else
    warn "ausearch no disponible; omitiendo check de AVCs"
fi

echo
if [[ $fail -gt 0 ]]; then
    echo "RESULT: $fail check(s) fallaron."
    exit 1
fi
echo "RESULT: OK"
exit 0
