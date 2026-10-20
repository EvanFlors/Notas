# Starter — ans-01-01-connect-to-vms

Esta actividad es **guiada**: hay dos modos de ejecución, elige uno.

## Pasos comunes

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/ans-01-01
   cd /tmp/ans-01-01
   ```
3. Verifica Ansible:
   ```bash
   ansible --version    # ansible-core >= 2.14 recomendado
   ```
   Si no lo tienes: `pipx install --include-deps ansible`.

## Modo A — solo localhost (recomendado como primera pasada)

Crea `/tmp/ans-01-01/inventory.yml`:

```yaml
all:
  children:
    managed:
      hosts:
        localhost:
          ansible_connection: local
      vars:
        ansible_python_interpreter: /usr/bin/python3
```

Y corre los pasos 5.3–5.5 del README principal.

## Modo B — localhost + 2 contenedores Ubuntu

Requiere `docker` disponible. Copia el `docker-compose.yml` y el `Dockerfile` de este starter y arranca:

```bash
cp docker-compose.yml Dockerfile /tmp/ans-01-01/
cd /tmp/ans-01-01
ssh-keygen -t ed25519 -N '' -f ./id_ed25519   # clave sólo para esta práctica
cp id_ed25519.pub authorized_keys
docker compose up -d --build
```

Inventory sugerido para Modo B:

```yaml
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

Luego el mismo `ping` y `shell -a uptime`.

## Validar

```bash
bash <ruta-repo>/courses/ansible/01-cm-vs-iac-setup-inventory-and-adhoc/activities/01-connect-to-vms/tests/validate.sh /tmp/ans-01-01
```

## Limpieza

```bash
cd /tmp/ans-01-01 && docker compose down -v 2>/dev/null || true
rm -rf /tmp/ans-01-01
```
