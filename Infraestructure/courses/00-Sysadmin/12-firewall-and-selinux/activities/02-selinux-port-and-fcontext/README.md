# Actividad 02 — SELinux: nginx en un puerto no estándar

**Tipo:** debug · **Duración:** 60 min · **Nivel:** avanzado

## Objetivo

Diagnosticar y arreglar un fallo real: `nginx` configurado para escuchar en `8443/tcp` no arranca bajo SELinux enforcing. Resolverlo **sin desactivar SELinux**, usando `semanage port` y, si hace falta, `restorecon`.

## Requisitos

- VM con **SELinux enforcing** (Fedora, Rocky, Alma, RHEL, CentOS Stream).
- `nginx`, `policycoreutils-python-utils` (para `semanage`, `audit2allow`).
- `sudo` o root.

```bash
sudo dnf install -y nginx policycoreutils-python-utils
getenforce   # debe decir Enforcing
```

## Escenario

Un compañero cambió la config de `nginx` para escuchar en `8443` (porque 443 lo usa otro servicio). El servicio no arranca:

```
# systemctl start nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
```

Lee `starter/scenario.md` para reproducir el entorno exacto.

## Lo que debes entregar

1. Un **diagnóstico escrito** (3–6 líneas) con:
   - El comando que te permitió confirmar que es SELinux (no firewall, no permisos DAC, no config de nginx).
   - El AVC concreto que leíste y qué pedía (`name_bind` sobre `unreserved_port_t`, etc.).
2. Un **script `fix.sh`** que:
   - Comprueba prerrequisitos.
   - Añade el puerto `8443` al tipo `http_port_t` con `semanage port -a`.
   - Reinicia `nginx`.
   - Verifica que escucha en `8443` (`ss -ltnpZ`).
3. La ejecución de `bash tests/validate.sh` con `RESULT: OK`.

## Qué **no** hacer

- **No** ejecutes `setenforce 0` como "solución". Es diagnóstico, no fix.
- **No** ejecutes `semodule -i` con la salida cruda de `audit2allow` para este caso. El problema está gobernado por el tipo del puerto, no requiere módulo custom.
- **No** cambies el puerto de vuelta a 443 para "evitar" SELinux. El objetivo es aprender a convivir con enforcing.

## Pistas

- Para listar los puertos ya etiquetados como `http_port_t`:
  ```bash
  sudo semanage port -l | grep http_port_t
  ```
- Para añadir el puerto:
  ```bash
  sudo semanage port -a -t http_port_t -p tcp 8443
  ```
  Si ya existe en otro tipo, usa `-m` (modificar) en vez de `-a` (añadir).
- `restorecon` **no** aplica a esta tarea (restorecon es para contextos de ficheros). Lo mencionamos porque la actividad original incluye el patrón de combinarlo con `semanage fcontext` cuando el contenido vive en un path no estándar; aquí sólo tocamos el puerto. Tu `fix.sh` puede incluirlo opcionalmente para `/var/www` si cambias el `root` en nginx.

## Validación

`tests/validate.sh` comprueba:

- SELinux en `Enforcing`.
- `nginx` activo (`systemctl is-active nginx`).
- `nginx` escuchando en `8443/tcp`.
- `semanage port -l` muestra `8443` dentro de `http_port_t`.
- No hay AVCs de `nginx` sobre `name_bind` 8443 en los últimos 5 minutos.

## Solución

En `solution/fix.sh` tienes la referencia completa. Léela sólo después de intentarlo.
