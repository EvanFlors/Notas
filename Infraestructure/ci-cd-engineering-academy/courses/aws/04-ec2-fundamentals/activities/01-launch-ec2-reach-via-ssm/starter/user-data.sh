# TODO: anade el shebang `#!/usr/bin/env bash` como primera linea
# TODO: anade `set -euo pipefail` (en user-data queremos fallo duro)
# TODO: anade redireccion unificada a /var/log/user-data.log con:
#         exec > >(tee -a /var/log/user-data.log) 2>&1
# TODO: anade un `trap 'echo "[user-data] FAILED at line $LINENO (exit $?)"' ERR`

echo "[user-data] START $(date -Is)"

# Paquetes (idempotente).
dnf -y install nginx jq awscli

# Config nginx atomica.
TMP=$(mktemp)
cat > "$TMP" <<'CONF'
server {
  listen 80 default_server;
  server_name _;
  location /healthz { return 200 "ok\n"; }
  location /        { return 200 "aws-04 ssm demo\n"; }
}
CONF
install -o root -g root -m 0644 "$TMP" /etc/nginx/conf.d/hello.conf
rm -f "$TMP"

# Arrancar y habilitar servicio (idempotente).
systemctl enable --now nginx

# TODO: anade un health check con reintentos:
#   for i in 1 2 3 4 5; do
#     if curl -fsS http://127.0.0.1/healthz >/dev/null; then
#       echo "[user-data] healthz OK (try $i)"
#       break
#     fi
#     echo "[user-data] healthz not ready (try $i), sleeping 2s..."
#     sleep 2
#     if [ "$i" = "5" ]; then
#       echo "[user-data] ERROR: healthz never came up"
#       exit 1
#     fi
#   done

echo "[user-data] DONE $(date -Is)"
