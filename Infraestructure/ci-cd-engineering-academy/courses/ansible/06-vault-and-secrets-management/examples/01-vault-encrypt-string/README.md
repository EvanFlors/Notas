# Ejemplo 01 — `ansible-vault encrypt_string`

> Ejecutable localmente. Encripta un **valor individual** y pégalo dentro de `group_vars/`. Objetivo: ver el formato `!vault |` y entender el trade-off vs encriptar archivos enteros.

## 1. Setup

```bash
mkdir -p /tmp/ans-06-ex01 && cd /tmp/ans-06-ex01
echo 'fake-password-not-real' > vault_pass
chmod 0600 vault_pass
```

> **Importante:** `fake-password-not-real` es la contraseña del vault, **no** el secreto. Es publica a propósito para que el ejemplo sea reproducible.

## 2. Encriptar un string

```bash
export PATH="$HOME/Library/Python/3.10/bin:$PATH"  # macOS si instalaste con pip --user
ansible-vault encrypt_string --vault-password-file vault_pass \
  'fake-db-password-never-real' \
  --name 'db_password'
```

Salida esperada (los bytes hex cambian cada vez):

```yaml
db_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          62313365396662343061393464...
```

## 3. Pegarlo en un `group_vars/`

```bash
mkdir -p group_vars
cat > group_vars/all.yml <<'YAML'
# Variables normales en claro: diffs legibles.
app_name: fastapi-demo
app_port: 8000

# Secreto encriptado puntual: usa el bloque de arriba.
# Reemplaza el bloque pegandolo tal cual.
db_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          <pega aqui el output de encrypt_string>
YAML
```

## 4. Comprobar que Ansible lo lee

```bash
cat > playbook.yml <<'YAML'
- hosts: localhost
  gather_facts: false
  tasks:
    - name: Mostrar que la variable esta descifrada
      ansible.builtin.debug:
        msg: "db_password tiene {{ db_password | length }} caracteres"
      no_log: false  # a proposito en el ejemplo; en prod ponlo a true
YAML

ansible-playbook --vault-password-file vault_pass playbook.yml
```

Salida esperada: `db_password tiene 27 caracteres` (longitud de `fake-db-password-never-real`).

## 5. Observa

- El `!vault |` es un **tag YAML custom** que Ansible resuelve descifrando.
- Puedes mezclar vars en claro y encriptadas en el mismo archivo → `git diff` sigue siendo legible.
- Si cambias el valor, re-ejecutas `encrypt_string`. No hay `edit_string`.

## 6. Limpieza

```bash
cd / && rm -rf /tmp/ans-06-ex01
```
