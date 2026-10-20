# Starter — ans-09-01-build-ami-with-packer-and-ansible

Esta actividad es un **guided-lab**: produces 2 archivos (HCL + YAML) + 1 Markdown. **Todo se valida en local** — no se construye ninguna AMI real.

## Pasos

1. Lee `../README.md` completo y recorre `../../../examples/02-packer-ansible-ami/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/ans-09-01
   cd /tmp/ans-09-01
   ```
3. Escribe los 3 archivos (nombres exactos):
   - `webapp.pkr.hcl` — plantilla Packer HCL2.
   - `playbook.yml` — playbook Ansible que se usa como provisioner.
   - `README-INTENT.md` — documento de intención con 4 secciones.
4. Valida localmente (si tienes las herramientas instaladas):
   ```bash
   # HCL (si tienes packer):
   cd /tmp/ans-09-01
   packer fmt -check webapp.pkr.hcl
   packer init .
   packer validate .

   # Playbook (si tienes ansible-core):
   ansible-playbook --syntax-check playbook.yml
   ```
5. Pasa el validador del repo (hace todo lo anterior + chequeos estructurales + marca SKIP si falta herramienta):
   ```bash
   bash <ruta-repo>/courses/ansible/09-hybrid-with-terraform-packer-and-awx-aap/activities/01-build-ami-with-packer-and-ansible/tests/validate.sh /tmp/ans-09-01
   ```
6. Compara tus archivos con los de `../solution/` para autoevaluarte.

## Esqueletos útiles

### Esqueleto Packer HCL2

```hcl
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.3.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.1"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "app_version" {
  type        = string
  description = "App version baked into the AMI name"
  default     = "0.1.0"
}

source "amazon-ebs" "al2023" {
  region        = var.region
  instance_type = "t3.micro"
  ami_name      = "webapp-${var.app_version}-{{timestamp}}"

  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-x86_64"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  ssh_username = "ec2-user"
}

build {
  sources = ["source.amazon-ebs.al2023"]

  provisioner "ansible" {
    playbook_file = "./playbook.yml"
    user          = "ec2-user"
    use_proxy     = false
    extra_arguments = [
      "--extra-vars", "app_version=${var.app_version}",
      "-v"
    ]
  }
}
```

### Esqueleto playbook

```yaml
---
- name: Bake webapp AMI
  hosts: all
  become: true
  gather_facts: true

  vars:
    app_user: webapp

  tasks:
    - name: Install packages
      ansible.builtin.dnf:
        name:
          - nginx
          - python3
        state: present

    - name: Create service user
      ansible.builtin.user:
        name: "{{ app_user }}"
        system: true
        shell: /sbin/nologin

    - name: Enable nginx (will start on first boot)
      ansible.builtin.systemd:
        name: nginx
        enabled: true
```

### Esqueleto README-INTENT.md

```markdown
# README-INTENT — webapp AMI

## Que se hornea
<nginx, user de servicio, cloudwatch-agent, ...>

## Que NO se hornea
<secretos (van vía user-data + Secrets Manager / Parameter Store), ...>

## Provisioner ansible vs ansible-local
<por qué elegimos uno u otro>

## Como consume Terraform el ami_id
<packer-manifest.json → jq → variable TF → aws_instance>
```

> El validador comprueba estructura (grep + packer validate si está + syntax-check si está). La corrección semántica (¿instala realmente nginx?, ¿la AMI arranca?) **no** se verifica aquí — es parte del build real.
