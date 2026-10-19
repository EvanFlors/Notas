# Role `webserver`

Instala nginx y lo configura como reverse proxy a `127.0.0.1:{{ webserver_upstream_port }}`.

## Variables

| Variable                   | Default     | Descripción                             |
|----------------------------|-------------|-----------------------------------------|
| `webserver_port`           | `80`        | Puerto en el que escucha nginx.         |
| `webserver_upstream_port`  | `8000`      | Puerto de la app upstream.              |
| `webserver_server_name`    | `localhost` | `server_name` del vhost.                |

## OS soportados

- Ubuntu 22.04, 24.04
- Debian 12
- RHEL / Rocky 9

## Handlers expuestos

- `reload nginx`

## Ejemplo

```yaml
- hosts: web
  become: true
  roles:
    - role: webserver
      vars:
        webserver_port: 80
        webserver_upstream_port: 8000
```

## Dependencies

- `common` — crea el usuario `appuser` sobre el que la app upstream se ejecutará.
