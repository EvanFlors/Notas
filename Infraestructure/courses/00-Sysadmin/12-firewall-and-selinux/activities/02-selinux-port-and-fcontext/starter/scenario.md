# Escenario — nginx no arranca en 8443

Reproduce el entorno en una VM con SELinux enforcing y nginx instalado.

## 1. Prerrequisitos

```bash
sudo dnf install -y nginx policycoreutils-python-utils
sudo setenforce 1
getenforce   # debe decir: Enforcing
```

En algunas distros `8443` ya forma parte de `http_port_t`. Para forzar el escenario de la actividad, usaremos un puerto no estándar que SÍ está libre: **9443**. Si tu distro ya tiene 8443 etiquetado, sustituye 8443 → 9443 en todo lo que sigue (y en tu `fix.sh` y en el validador configurable vía `PORT=9443`).

Comprueba:

```bash
sudo semanage port -l | grep -E 'http_port_t|9443|8443'
```

Si ves `9443` dentro de `http_port_t`, elige otro puerto no listado (p. ej. `9444`) y usa esa variable.

## 2. Configurar nginx para escuchar en el puerto no etiquetado

Edita `/etc/nginx/nginx.conf` y en el bloque `server` por defecto cambia:

```nginx
listen       80 default_server;
listen       [::]:80 default_server;
```

por:

```nginx
listen       8443 default_server;
listen       [::]:8443 default_server;
```

(o `9443` si ese fue el puerto que elegiste arriba).

## 3. Intentar arrancar

```bash
sudo systemctl restart nginx
```

Debe fallar. Comprueba:

```bash
systemctl status nginx --no-pager
journalctl -xeu nginx --no-pager | tail -30
```

Verás algo como `bind() to 0.0.0.0:8443 failed (13: Permission denied)`.

## 4. Confirmar que es SELinux

```bash
sudo ausearch -m AVC -ts recent | tail -40
```

Si ves una línea con `avc: denied { name_bind }` sobre `tcontext=system_u:object_r:unreserved_port_t` y `scontext=system_u:system_r:httpd_t`, es exactamente este caso.

## 5. Tu trabajo

Arreglarlo sin apagar SELinux. Escribe un `fix.sh` que lo resuelva de forma reproducible y pasa `tests/validate.sh`.
