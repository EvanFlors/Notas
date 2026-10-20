# Ejemplo 02 — Múltiples vault IDs (`dev@` y `prod@`)

> Ejecutable localmente. Demuestra cómo separar secretos de **dev** y **prod** con dos passwords distintas y cómo Ansible selecciona la correcta por label.

## 1. Setup

```bash
mkdir -p /tmp/ans-06-ex02/{group_vars,.vault} && cd /tmp/ans-06-ex02
echo 'fake-dev-vault-pass'  > .vault/dev_pass
echo 'fake-prod-vault-pass' > .vault/prod_pass
chmod 0600 .vault/*
export PATH="$HOME/Library/Python/3.10/bin:$PATH"
```

## 2. Crear dos archivos de variables (en claro) y encriptar con labels distintos

```bash
cat > group_vars/dev.yml <<'YAML'
env: dev
api_token: fake-dev-token-not-real
YAML

cat > group_vars/prod.yml <<'YAML'
env: prod
api_token: fake-prod-token-not-real
YAML

ansible-vault encrypt --vault-id dev@.vault/dev_pass   group_vars/dev.yml
ansible-vault encrypt --vault-id prod@.vault/prod_pass group_vars/prod.yml
```

Verifica el header:

```bash
head -1 group_vars/dev.yml   # $ANSIBLE_VAULT;1.2;AES256;dev
head -1 group_vars/prod.yml  # $ANSIBLE_VAULT;1.2;AES256;prod
```

El label (`dev` / `prod`) va en el header → Ansible sabe qué password buscar.

## 3. Ejecutar con los dos IDs

```bash
cat > inventory.ini <<'INI'
[dev]
localhost ansible_connection=local

[prod]
localhost ansible_connection=local
INI

cat > playbook.yml <<'YAML'
- hosts: all
  gather_facts: false
  tasks:
    - name: Mostrar entorno
      ansible.builtin.debug:
        msg: "env={{ env }} token_len={{ api_token | length }}"
YAML

# Con los dos vault IDs, cada archivo se descifra con su password.
ansible-playbook -i inventory.ini playbook.yml \
  --vault-id dev@.vault/dev_pass \
  --vault-id prod@.vault/prod_pass \
  --limit dev
```

## 4. Qué pasa si un dev **no** tiene la password de prod

```bash
# Simula un ingeniero sin acceso a prod: pasa solo el id de dev.
ansible-playbook -i inventory.ini playbook.yml \
  --vault-id dev@.vault/dev_pass \
  --limit prod
```

Ansible intenta descifrar `prod.yml` con la password de dev, falla, y aborta:

```text
ERROR! Attempting to decrypt but no vault secrets found
```

Este es exactamente el comportamiento deseado: **sin la password de prod no se puede tocar prod**, aunque el archivo encriptado sea legible en el repo.

## 5. Rotar la password de dev

```bash
echo 'fake-dev-rotated-pass' > .vault/dev_pass_new
chmod 0600 .vault/dev_pass_new

ansible-vault rekey \
  --vault-id dev@.vault/dev_pass \
  --new-vault-id dev@.vault/dev_pass_new \
  group_vars/dev.yml
```

El archivo encriptado cambia; `dev.yml` ahora solo se descifra con la nueva password. Los runners/engineers que tenian la vieja ya no pueden leerlo.

## 6. Limpieza

```bash
cd / && rm -rf /tmp/ans-06-ex02
```
