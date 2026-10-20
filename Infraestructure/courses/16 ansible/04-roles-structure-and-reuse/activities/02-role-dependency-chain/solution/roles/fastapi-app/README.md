# Role `fastapi-app`

Despliega una app FastAPI (o cualquier servicio Python simple) como unidad systemd. Diseñada para servirse detrás del role `webserver`.

## Variables

| Variable              | Default           | Descripción                       |
|-----------------------|-------------------|-----------------------------------|
| `fastapi_app_name`    | `fastapi-app`     | Nombre del service de systemd.    |
| `fastapi_app_port`    | `8000`            | Puerto que la app expone.         |
| `fastapi_app_user`    | `appuser`         | Usuario con el que corre.         |
| `fastapi_app_workdir` | `/opt/fastapi-app`| Working directory.                |

## OS soportados

- Ubuntu 22.04, 24.04
- Debian 12
- RHEL / Rocky 9

## Handlers expuestos

- `restart fastapi-app`

## Ejemplo

```yaml
- hosts: app
  become: true
  roles:
    - role: fastapi-app
      vars:
        fastapi_app_port: 8001
```

## Dependencies

- `webserver` — el role `fastapi-app` asume que hay un reverse proxy delante que apunta a `127.0.0.1:{{ fastapi_app_port }}`. `webserver` a su vez depende de `common`.
