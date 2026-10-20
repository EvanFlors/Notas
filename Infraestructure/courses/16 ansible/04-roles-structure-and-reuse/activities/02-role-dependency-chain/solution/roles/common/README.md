# Role `common`

Baseline minimo del host. Crea el usuario de servicio y fija la timezone. Base para el resto de roles de la cadena.

## Variables

| Variable               | Default        | Descripción                       |
|------------------------|----------------|-----------------------------------|
| `common_timezone`      | `UTC`          | Timezone del host.                |
| `common_appuser`       | `appuser`      | Usuario de servicio.              |
| `common_appuser_home`  | `/home/appuser`| Home del usuario.                 |

## OS soportados

- Ubuntu 22.04, 24.04
- Debian 12
- RHEL / Rocky 9

## Ejemplo

```yaml
- hosts: all
  become: true
  roles:
    - role: common
      vars:
        common_timezone: Europe/Madrid
```

## Dependencies

Ninguna. Este role es la raíz de la cadena.
