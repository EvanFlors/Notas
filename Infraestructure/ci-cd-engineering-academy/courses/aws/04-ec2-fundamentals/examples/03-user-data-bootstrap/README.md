# Ejemplo 03 — User-data: bootstrap idempotente y defensivo

> Lectura y análisis. Objetivo: ver patrones de `user-data` que **no se rompen** si se re-ejecutan y que **loguean** lo suficiente para debuggear sin entrar a la caja.

## 1. Esqueleto recomendado

```bash
#!/usr/bin/env bash
# user-data.sh — bootstrap de la EC2 "web".
#
# Ejecutado por cloud-init como root en el primer arranque.
# Diseno: idempotente (puede re-correrse via `cloud-init clean && cloud-init init`).

set -euo pipefail

# -----------------------------------------------------------------------------
# 1. Logging — todo el output a /var/log/user-data.log Y a la consola
# -----------------------------------------------------------------------------
LOG=/var/log/user-data.log
exec > >(tee -a "$LOG") 2>&1

echo "[user-data] START $(date -Is)"
trap 'echo "[user-data] FAILED at line $LINENO (exit $?)"' ERR

# -----------------------------------------------------------------------------
# 2. Variables (se pueden inyectar via templatefile() desde Terraform)
# -----------------------------------------------------------------------------
APP_USER="webapp"
APP_DIR="/opt/webapp"
APP_VERSION="${app_version:-1.0.0}"   # placeholder templatefile

# -----------------------------------------------------------------------------
# 3. Paquetes del sistema (dnf es idempotente)
# -----------------------------------------------------------------------------
dnf -y install nginx jq awscli

# -----------------------------------------------------------------------------
# 4. Usuario de aplicacion (idempotente: no falla si ya existe)
# -----------------------------------------------------------------------------
if ! id "$APP_USER" >/dev/null 2>&1; then
  useradd --system --home-dir "$APP_DIR" --shell /sbin/nologin "$APP_USER"
fi

install -d -o "$APP_USER" -g "$APP_USER" -m 0755 "$APP_DIR"

# -----------------------------------------------------------------------------
# 5. Config con write-and-move atomico (evita leer un fichero a medio escribir)
# -----------------------------------------------------------------------------
TMP=$(mktemp)
cat > "$TMP" <<CONF
server {
  listen 80 default_server;
  server_name _;
  location /healthz { return 200 "ok\n"; }
  location /        { return 200 "webapp $APP_VERSION\n"; }
}
CONF
install -o root -g root -m 0644 "$TMP" /etc/nginx/conf.d/hello.conf
rm -f "$TMP"

# -----------------------------------------------------------------------------
# 6. Secretos — ejemplo: leer de SSM Parameter Store usando el instance profile
# -----------------------------------------------------------------------------
# (Esto necesita que el rol tenga ssm:GetParameter sobre el ARN del parametro.)
# API_KEY=$(aws ssm get-parameter --name "/webapp/api-key" --with-decryption \
#            --query 'Parameter.Value' --output text)
# echo "API_KEY=$API_KEY" > "$APP_DIR/.env"
# chown "$APP_USER:$APP_USER" "$APP_DIR/.env"
# chmod 0600 "$APP_DIR/.env"

# -----------------------------------------------------------------------------
# 7. Servicios (enable --now es idempotente)
# -----------------------------------------------------------------------------
systemctl enable --now nginx

# -----------------------------------------------------------------------------
# 8. Health check propio (fail-fast si algo no quedo arriba)
# -----------------------------------------------------------------------------
for i in 1 2 3 4 5; do
  if curl -fsS http://127.0.0.1/healthz >/dev/null; then
    echo "[user-data] healthz OK (try $i)"
    break
  fi
  echo "[user-data] healthz not ready (try $i), sleeping 2s..."
  sleep 2
  if [ "$i" = "5" ]; then
    echo "[user-data] ERROR: healthz never came up"
    exit 1
  fi
done

echo "[user-data] DONE $(date -Is)"
```

## 2. Checklist de buenas prácticas

| Práctica | Por qué |
|----------|---------|
| `#!/usr/bin/env bash` | Portabilidad (no asume `/bin/bash` concreto). |
| `set -euo pipefail` | Fallar temprano, nunca enmascarar errores de pipe. |
| `exec > >(tee -a LOG) 2>&1` | Log unificado, revisable sin entrar a la EC2 (CloudWatch Agent lo recoge). |
| `trap ... ERR` | Mensaje legible si algo peta. |
| Comandos nativamente idempotentes (`dnf install`, `systemctl enable --now`, `install -D`) | Permite re-correr sin estado residual. |
| `install -o -g -m` en vez de `cp && chmod && chown` | Atómico, correcto, 1 línea. |
| `useradd --system` con guard `id "$APP_USER"` | No falla en re-run. |
| `mktemp` + `install` para configs | Escritura atómica — nginx no lee un archivo a medias. |
| Health check propio al final | Si no responde, el user-data falla y lo ves rápido. |

## 3. Antipatrones típicos

```bash
# MAL: NO manejar errores
yum install nginx          # puede fallar silente

# MAL: crear usuario sin guard
useradd webapp             # falla en re-run

# MAL: config no atomica
echo "server { ... }" > /etc/nginx/conf.d/x.conf   # si falla a medias deja basura

# MAL: secretos hardcodeados
echo "API_KEY=prod_abc123" > .env                  # queda en user-data (visible via IMDS!)

# MAL: curl | bash sin pin
curl -s https://install.example.com/foo.sh | bash   # supply chain pwn
```

## 4. Dónde quedan los logs

- `/var/log/user-data.log` — lo que vimos arriba, controlado por nosotros.
- `/var/log/cloud-init.log` — logs de cloud-init (invocaciones, etapas).
- `/var/log/cloud-init-output.log` — stdout/stderr de los módulos de cloud-init (incluye el nuestro).

Si al debuggear algo no arranca:

```bash
aws ssm start-session --target i-xxxx
sudo tail -n 200 /var/log/user-data.log
sudo cat /var/log/cloud-init-output.log
```

## 5. Cómo lo inyectas desde Terraform

Dos formas comunes:

### a) Script estático

```hcl
resource "aws_instance" "app" {
  user_data = file("${path.module}/user-data.sh")
}
```

### b) Script con variables (template)

```hcl
resource "aws_instance" "app" {
  user_data = templatefile("${path.module}/user-data.sh.tpl", {
    app_version = "1.2.3"
    bucket_name = aws_s3_bucket.assets.bucket
  })
}
```

Dentro del `.tpl` usas `${app_version}`, `${bucket_name}`. (Ojo: `$` literal se escapa como `$$`.)

En **launch templates** el campo equivalente es `user_data` también, pero **base64-encoded**: `user_data = base64encode(file(...))`.
