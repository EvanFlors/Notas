# REFERENCE — ans-01-01-connect-to-vms

> Una referencia razonada; no es la única respuesta correcta.

## 1. Inventory Modo A (localhost)

```yaml
# inventory.yml
all:
  children:
    managed:
      hosts:
        localhost:
          ansible_connection: local
      vars:
        ansible_python_interpreter: /usr/bin/python3
```

## 2. Inventory Modo B (2 contenedores)

```yaml
# inventory.yml
all:
  children:
    managed:
      hosts:
        node-1:
          ansible_host: 127.0.0.1
          ansible_port: 2201
        node-2:
          ansible_host: 127.0.0.1
          ansible_port: 2202
      vars:
        ansible_user: ansible
        ansible_ssh_private_key_file: ./id_ed25519
        ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        ansible_python_interpreter: /usr/bin/python3
```

Decisiones:

- `managed` como grupo único para distinguir "mis targets" de `all` (que incluye `ungrouped`).
- `ansible_python_interpreter` fijado para evitar el *warning* "Discovered python interpreter".
- En Modo B, `StrictHostKeyChecking=no` es aceptable **solo** porque es laboratorio local y efímero.

## 3. Verificación esperada

```bash
ansible-inventory -i inventory.yml --graph
# @all:
#   |--@managed:
#   |  |--localhost        (Modo A)
#   |  |--node-1           (Modo B)
#   |  |--node-2           (Modo B)
#   |--@ungrouped:

ansible -i inventory.yml all -m ping
# localhost | SUCCESS => { "ping": "pong", ... }

ansible -i inventory.yml managed -m shell -a "uptime"
#  09:12:34 up  2:17,  3 users,  load average: 0.42, 0.38, 0.35
```

## 4. Errores típicos y cómo diagnosticarlos

| Síntoma | Causa probable | Diagnóstico |
|---------|----------------|-------------|
| `UNREACHABLE: ssh: connect to host 127.0.0.1 port 2201: Connection refused` | Contenedor no arriba o puerto mal mapeado | `docker ps`, `nc -zv 127.0.0.1 2201` |
| `Permission denied (publickey)` | `authorized_keys` sin la pub correcta o permisos malos | `docker exec -it ans01-node-1 ls -la /home/ansible/.ssh` |
| `/bin/sh: 1: /usr/bin/python3: not found` | Imagen sin Python | el Dockerfile del starter ya lo instala; revisa `apt-get install python3` |
| `WARNING: Platform ... is using the discovered Python interpreter` | No fijaste `ansible_python_interpreter` | añade la var al grupo |

## 5. Lectura del `--list`

El `--list` incluye el bloque `_meta.hostvars` con las variables resueltas por host, y luego los grupos con `hosts: [...]`. Es lo que un playbook consume: por eso vale la pena capturarlo como artefacto y revisar que lo que crees que le vas a pasar a Ansible, efectivamente le llega.
