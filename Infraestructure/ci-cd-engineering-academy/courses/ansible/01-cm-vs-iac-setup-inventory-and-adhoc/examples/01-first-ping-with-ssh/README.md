# Ejemplo 01 — First ping con SSH

> Lectura y análisis. Objetivo: fijar qué pasa debajo cuando corres `ansible all -m ping`.

## 1. El escenario

Instalaste Ansible con `pipx install --include-deps ansible`. Tienes tu laptop (control node) y un `localhost` como primer target. Antes de automatizar nada, quieres confirmar que todas las piezas hablan entre sí.

## 2. Inventory mínimo

```yaml
# hosts.yml
all:
  hosts:
    localhost:
      ansible_connection: local
```

`ansible_connection: local` evita abrir SSH contra ti mismo (no necesitas tener `sshd` activo).

## 3. Ad-hoc ping

```bash
ansible -i hosts.yml all -m ping
```

Salida esperada:

```
localhost | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

## 4. Qué pasó por dentro

1. Ansible leyó `hosts.yml` y resolvió el grupo `all` → `[localhost]`.
2. Vio `ansible_connection: local` → usó el *connection plugin* `local` (no SSH).
3. Serializó el módulo `ping` (un script Python de ~30 líneas) a `~/.ansible/tmp/ansible-tmp-.../AnsiballZ_ping.py`.
4. Lo ejecutó con el intérprete Python detectado (`/usr/bin/python3`).
5. El módulo imprimió `{"changed": false, "ping": "pong"}` en JSON por stdout.
6. Ansible parseó el JSON y pintó el `SUCCESS => ...`.

Si cambiaras `ansible_connection: local` por SSH apuntando a una máquina remota, los pasos 3–5 serían **sobre el target**, con la copia del módulo transportada por SSH.

## 5. Variantes útiles

```bash
# Verbose (puedes ver la copia del módulo y el intérprete elegido):
ansible -i hosts.yml all -m ping -vvv

# Múltiples hosts (prueba después contra VMs reales o contenedores):
ansible -i hosts.yml all -m ping --forks 20

# Shell crudo (útil si Python no está en el target):
ansible -i hosts.yml all -m raw -a "uptime"
```

## 6. Qué no es `ping`

- **No es ICMP**: no abre un socket raw ni pide `ping` del SO.
- **Verifica** 3 cosas: conectividad del connection plugin + existencia de Python en el target + ejecución correcta del módulo.
- Si falla, el error te dice cuál de las 3 piezas rompió.

## 7. Lectura relacionada

- `theory/lesson.md` §2 (modelo push-agentless-SSH).
- `examples/02-inventory-yaml-vs-ini/` para variar el formato del inventory.
