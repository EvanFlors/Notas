# Ejemplo 02 — `group_vars` y `host_vars` sobrepuestos

Tres hosts "virtuales" (todos apuntan a `localhost`), dos grupos (`web` y `db`), y un host (`web2`) con override en `host_vars/`. Al ejecutar el playbook verás, para cada host, qué valor final tiene la variable `app_port` y de dónde viene.

Jerarquía (de menor a mayor precedence):

1. `group_vars/all.yml` → `app_port: 8000`
2. `group_vars/web.yml` → `app_port: 8080`
3. `host_vars/web2.yml` → `app_port: 9090`

Resultado esperado:

| Host | Grupos | `app_port` final |
|------|--------|------------------|
| `web1` | `web`, `all` | **8080** (de `group_vars/web.yml`) |
| `web2` | `web`, `all` | **9090** (override en `host_vars/web2.yml`) |
| `db1`  | `db`, `all`  | **8000** (de `group_vars/all.yml`) |

## Ejecutar

```bash
cd examples/02-group-vars-and-overrides
ansible-playbook -i inventory.yml playbook.yml
```

El playbook simplemente hace `debug` del valor para cada host.

## Qué cambiar para experimentar

- Añade `app_port: 7777` como **extra var**: `-e app_port=7777`. **Todos** los hosts caerán a `7777` (extra vars gana contra todo).
- Añade `vars:` en la play con `app_port: 1234`. `web1` y `db1` caerán a `1234` (play vars > inventory group_vars), pero `web2` seguirá en `9090` solo si lo pones también en `host_vars`. Ojo: en realidad `playbook host_vars` (nivel 9) también gana a play vars (nivel 11)? **No**: `play vars` (nivel 11) gana a `inventory host_vars` (nivel 8). Verifícalo tú.
