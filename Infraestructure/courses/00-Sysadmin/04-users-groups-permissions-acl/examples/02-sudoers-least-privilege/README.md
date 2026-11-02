# Ejemplo 02 — sudoers con mínimo privilegio

## Qué muestra

Cómo escribir un fragmento en `/etc/sudoers.d/` que concede a un grupo (`webops`) **solo** los comandos necesarios para operar `nginx`, sin dar un shell de root ni permitir reiniciar otros servicios.

## Fragmento canónico

Archivo `/etc/sudoers.d/10-webops-nginx` (modo `0440`, propietario `root:root`):

```sudoers
# ------------------------------------------------------------------
# 10-webops-nginx
#   Permite al grupo 'webops' operar el servicio nginx (y SOLO nginx).
#   No se otorga shell, ni edición de configuración.
# ------------------------------------------------------------------

Cmnd_Alias NGINX_OPS = /usr/bin/systemctl restart nginx, \
                       /usr/bin/systemctl reload  nginx, \
                       /usr/bin/systemctl status  nginx, \
                       /usr/bin/systemctl is-active nginx, \
                       /usr/bin/journalctl -u nginx *

Defaults!NGINX_OPS   !requiretty
%webops  ALL=(root) NOPASSWD: NGINX_OPS
```

## Pasos para instalarlo

```bash
# 1. Crear el grupo y añadir un usuario de prueba
sudo groupadd -f webops
sudo usermod -aG webops $USER
newgrp webops   # (o cerrar sesión y volver)

# 2. Editar y validar
sudo visudo -f /etc/sudoers.d/10-webops-nginx
# pegar el fragmento de arriba y guardar

# 3. Verificar sintaxis manualmente (opcional, visudo ya la valida)
sudo visudo -cf /etc/sudoers.d/10-webops-nginx
#   -> /etc/sudoers.d/10-webops-nginx: parsed OK

# 4. Como usuario destino:
sudo -l
#   Debe listar NGINX_OPS, NOPASSWD
```

## Qué comprobar

Positivos (deben funcionar):

```bash
sudo systemctl status  nginx
sudo systemctl reload  nginx
sudo systemctl restart nginx
```

Negativos (deben fallar con "Sorry, user ... is not allowed"):

```bash
sudo systemctl restart sshd
sudo systemctl poweroff
sudo bash
sudo vi /etc/nginx/nginx.conf
```

## Detalles importantes

- **Rutas absolutas**: `systemctl` sin ruta no coincide salvo con `Defaults secure_path`. Siempre `/usr/bin/systemctl`.
- **Último argumento concreto**: `restart nginx`, no `restart *`. Un `*` dejaría `systemctl restart poweroff.target`.
- **`journalctl -u nginx *`**: el `*` permite flags adicionales (`--since`, `-n 100`), pero el `-u nginx` queda fijado.
- **Modo del archivo**: `0440 root:root`. `visudo` lo fuerza. Si lo editas con otra herramienta y queda `0644`, `sudo` lo **ignora silenciosamente** (archivo demasiado permisivo).
- **Nombre sin punto**: `10-webops-nginx` sí; `10-webops-nginx.conf` **no** (los nombres con `.` se omiten por diseño — igual que `~`).
- **NOPASSWD**: cómodo para automatización, discutible para humanos. Para una regla manejada por una persona, considera dejar el prompt y usar la caché por sesión (`timestamp_timeout`).

## Logging

```bash
sudo journalctl _COMM=sudo --since "10 min ago"
# ... COMMAND=/usr/bin/systemctl restart nginx
```

Cada invocación queda registrada con usuario, TTY, comando y resultado. Es la razón principal por la que `sudo` existe en vez de "dale la contraseña de root".
