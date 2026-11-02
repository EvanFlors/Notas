#!/usr/bin/env bash
# sys-12-02 — Solución de referencia.
#
# Añade el puerto PORT (default 8443) al tipo http_port_t para permitir
# que nginx bindee ahí bajo SELinux enforcing.
#
# USO:
#   sudo bash fix.sh                 # usa PORT=8443
#   sudo PORT=9443 bash fix.sh       # usa 9443 si 8443 ya está etiquetado
#
# No apaga SELinux. No modifica contextos de ficheros.

set -euo pipefail

PORT="${PORT:-8443}"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecútame como root (sudo)." >&2
    exit 1
fi

for bin in semanage ss systemctl getenforce; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "ERROR: falta '$bin' en PATH." >&2
        exit 1
    fi
done

mode="$(getenforce)"
if [[ "$mode" != "Enforcing" ]]; then
    echo "AVISO: SELinux está en '$mode', no en Enforcing." >&2
    echo "       El fix se aplicará igual, pero el objetivo del ejercicio es Enforcing." >&2
fi

echo "== 1. Estado actual del puerto $PORT en SELinux =="
current_type="$(semanage port -l | awk -v p=" $PORT," -v p2=" $PORT$" '
    $2=="tcp" { for (i=3;i<=NF;i++) if ($i==p || $i==p2 || $i==""p"" || $i==""p2"") print $1 }
' || true)"

if [[ -n "$current_type" ]]; then
    echo "Puerto $PORT ya está etiquetado como: $current_type"
    if [[ "$current_type" == "http_port_t" ]]; then
        echo "OK: nada que hacer en semanage port."
    else
        echo "== 2. Modificando etiqueta a http_port_t =="
        semanage port -m -t http_port_t -p tcp "$PORT"
    fi
else
    echo "== 2. Añadiendo $PORT/tcp a http_port_t =="
    semanage port -a -t http_port_t -p tcp "$PORT"
fi

echo "== 3. Verificando etiquetado =="
semanage port -l | grep -E "http_port_t.*\\<$PORT\\>" || {
    echo "FAIL: $PORT no aparece en http_port_t tras el cambio." >&2
    exit 1
}

echo "== 4. Reiniciando nginx =="
systemctl restart nginx

echo "== 5. Comprobando que nginx escucha en $PORT =="
sleep 1
if ss -ltnp 2>/dev/null | grep -E ":$PORT\\b" | grep -q nginx; then
    echo "OK: nginx escuchando en $PORT."
else
    echo "FAIL: nginx no está escuchando en $PORT. Revisa 'journalctl -xeu nginx'." >&2
    exit 1
fi

echo
echo "RESULT: OK. nginx corre en $PORT con SELinux Enforcing."
