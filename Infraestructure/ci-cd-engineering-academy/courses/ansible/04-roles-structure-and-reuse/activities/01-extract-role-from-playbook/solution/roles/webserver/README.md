# Role `webserver`

Instala nginx y despliega una config minimal parametrizada por variables. Pensado como entry point reutilizable para servir aplicaciones vía reverse proxy.

## Variables

### Sobreescribibles (`defaults/main.yml`)

| Variable                        | Default      | Descripción                              |
|---------------------------------|--------------|------------------------------------------|
| `webserver_port`                | `80`         | Puerto en el que escucha nginx.          |
| `webserver_server_name`         | `localhost`  | `server_name` del vhost.                 |
| `webserver_worker_processes`    | `auto`       | Directiva `worker_processes`.            |
| `webserver_worker_connections`  | `1024`       | Directiva `worker_connections`.          |
| `webserver_user`                | `www-data`   | Usuario con el que corre nginx.          |

### Internas (`vars/main.yml`) — no sobreescribir

| Variable                | Valor               | Por qué es interna                        |
|-------------------------|---------------------|-------------------------------------------|
| `webserver_pkg`         | `nginx`             | Nombre del paquete (depende del OS).      |
| `webserver_service`     | `nginx`             | Nombre del service.                       |
| `webserver_conf_path`   | `/etc/nginx/nginx.conf` | Path canónico; cambiarlo rompe el role. |

## OS soportados

- Ubuntu 22.04 (jammy), 24.04 (noble)
- Debian 12 (bookworm)
- RHEL / Rocky / AlmaLinux 9

## Handlers expuestos

- `reload nginx` — reload sin interrumpir conexiones (preferido para cambios de config).
- `restart nginx` — restart completo (sólo si lo necesitas de verdad).

## Ejemplo

```yaml
- hosts: web
  become: true
  roles:
    - role: webserver
      vars:
        webserver_port: 8080
        webserver_server_name: api.example.com
```

## Dependencies

Ninguna. Se puede componer con `common` desde el playbook.

## Changelog

- 1.0.0 — Primera versión. Nginx + template + handler reload.
