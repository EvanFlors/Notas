# Ejemplo 01 — Outputs de Terraform → inventario dinámico de Ansible

> Lectura y análisis. Sin ejecución (no requiere cuenta AWS activa). Objetivo: fijar el patrón *mutable* "TF crea → Ansible configura" con inventario dinámico por tag.

## 1. Topología del ejemplo

Imagina este Terraform (fragmento):

```hcl
resource "aws_instance" "web" {
  count         = 3
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"
  subnet_id     = module.vpc.private_subnets[count.index % 3]

  tags = {
    Name        = "web-${count.index}"
    Role        = "web"
    Environment = "production"
    ManagedBy   = "ansible"
  }
}

output "web_private_ips" {
  value = aws_instance.web[*].private_ip
}
```

Tras `terraform apply`, hay 3 instancias con tag `Role=web`, `Environment=production`, `ManagedBy=ansible`.

## 2. El inventario dinámico de Ansible

`inventory/aws_ec2.yml`:

```yaml
plugin: amazon.aws.aws_ec2
regions:
  - eu-west-1
filters:
  tag:ManagedBy: ansible
  tag:Environment: production
  instance-state-name: running
keyed_groups:
  - key: tags.Role
    prefix: role
hostnames:
  - private-ip-address
compose:
  ansible_host: private_ip_address
```

Lectura:

1. `plugin: amazon.aws.aws_ec2` — plugin oficial de la collection `amazon.aws`.
2. `regions` — dónde buscar.
3. `filters` — qué instancias quieres (tags + estado).
4. `keyed_groups` — construye grupos dinámicos. Con `key: tags.Role` + `prefix: role`, Ansible crea el grupo `role_web`.
5. `hostnames` — qué atributo usar como nombre de host (aquí, la IP privada).
6. `compose: ansible_host: private_ip_address` — SSH apunta a la IP privada.

## 3. Comprobar el inventario (sin playbook)

```bash
ansible-inventory -i inventory/aws_ec2.yml --graph
```

Salida esperada (con las 3 EC2 del tag `Role=web`):

```
@all:
  |--@aws_ec2:
  |  |--10.0.1.10
  |  |--10.0.1.11
  |  |--10.0.1.12
  |--@role_web:
  |  |--10.0.1.10
  |  |--10.0.1.11
  |  |--10.0.1.12
  |--@ungrouped:
```

> Nota: para correrlo de verdad necesitas credenciales AWS (`~/.aws/credentials` o `AWS_PROFILE`) y la collection instalada (`ansible-galaxy collection install amazon.aws`).

## 4. El playbook

`site.yml`:

```yaml
---
- name: Configure web tier
  hosts: role_web
  become: true
  gather_facts: true
  roles:
    - common
    - nginx
```

Ejecución:

```bash
ansible-playbook -i inventory/aws_ec2.yml site.yml
```

El playbook **no sabe** cuántas instancias hay ni cuáles son sus IPs. Pregunta al plugin, que pregunta a AWS, y se adapta a cada run.

## 5. Pipeline (orden que importa)

En CI (GitHub Actions, GitLab CI, Jenkins):

```yaml
jobs:
  deploy:
    steps:
      - uses: actions/checkout@v4
      - name: Terraform apply
        run: |
          cd infra/
          terraform init
          terraform apply -auto-approve
      - name: Ansible converge
        run: |
          cd config/
          ansible-galaxy collection install -r requirements.yml
          ansible-playbook -i inventory/aws_ec2.yml site.yml
```

Un **único job** ejecuta ambos. Si TF falla, Ansible no corre. Si Ansible falla, el run falla.

**Antipatrón**: dos jobs separados y confiar en humanos para "primero corre TF y luego Ansible".

## 6. Qué pasa cuando TF escala a 5 instancias

- `terraform apply` crea las 2 nuevas con los mismos tags.
- La próxima vez que Ansible corra, el plugin devuelve **5** hosts en `role_web`.
- El playbook aplica a los 5 — los 2 nuevos se configuran, los 3 viejos verifican que ya están correctos (0 changes).

Nada que cambiar en el repo de Ansible.

## 7. Dónde este patrón falla

- Si las instancias **se recrean** cada apply (porque TF cambia `user_data`), el inventario cambia constantemente y Ansible aplica en instancias "nuevas" que todavía están arrancando. Solución: `wait_for_connection` al inicio del play; o migrar a patrón 2.
- Si un operador hace `ssh` y edita un archivo a mano, Ansible lo revierte **al próximo run** — pero si nadie corre Ansible, el drift crece.
- Si la cuenta tiene **miles de EC2**, el filtro por tag puede ser lento. Hay que medir y usar `cache` del inventory plugin.

## 8. Preguntas de autocomprobación

1. ¿Qué pasa si en el filtro quitas `instance-state-name: running`?
2. ¿Cómo haces que `web-prod` y `web-stg` sean grupos separados sin cambiar el playbook?
3. Si quieres SSH por IP pública (porque las instancias son públicas), ¿qué cambias en el YAML del inventory?
4. ¿Por qué el pipeline debe ser un único job y no dos?
5. ¿Qué ganas si migras este patrón al patrón 2 (Packer + AMI)? ¿Qué pierdes?
