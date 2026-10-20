# Ejemplo 02 — Packer + Ansible → AMI inmutable

> Lectura y análisis. No se construye una AMI real (no requiere credenciales AWS). Objetivo: ver la **anatomía** de una plantilla Packer HCL2 que usa Ansible como provisioner.

## 1. Qué resuelve

Terminar el día con una AMI (snapshot EBS) que lleva **todo horneado**: SO base + runtime + agents + nginx + usuario de servicio + sysctl + logs config. Terraform solo tiene que `aws_instance { ami = packer_output_ami_id }` y en segundos la EC2 está lista.

Elimina:

- Ventana "arrancó pero no está configurada" (segundos vs minutos).
- Drift por edición manual (nadie `ssh`-ea porque la VM va a morir).
- Dos fuentes de verdad (TF para la topología, Ansible para la config pero *todo pre-horneado*).

## 2. Estructura típica del repo

```
packer/
├── webapp.pkr.hcl         # Plantilla Packer HCL2
├── playbook.yml           # Playbook Ansible que se corre dentro del build
├── requirements.yml       # Collections Ansible necesarias
└── files/
    └── nginx.conf         # Config pre-cocinada
```

## 3. La plantilla Packer

`webapp.pkr.hcl`:

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
  default     = "1.0.0"
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

  tags = {
    Name        = "webapp-${var.app_version}"
    BuiltBy     = "packer"
    BaseAMI     = "al2023"
    ManagedBy   = "ansible"
  }
}

build {
  name    = "webapp"
  sources = ["source.amazon-ebs.al2023"]

  provisioner "ansible" {
    playbook_file = "./playbook.yml"
    user          = "ec2-user"
    use_proxy     = false
    extra_arguments = [
      "--extra-vars", "nginx_port=80 app_version=${var.app_version}",
      "-v"
    ]
  }

  post-processor "manifest" {
    output = "packer-manifest.json"
  }
}
```

Lectura por bloques:

- **`packer { required_plugins { ... } }`**: declaración de plugins. `packer init .` los descarga.
- **`variable`**: parámetros tipados — `region` y `app_version` (esta última entra en el nombre de la AMI y en los extra-vars de Ansible, atando build con release).
- **`source "amazon-ebs" "al2023"`**: define cómo lanza la EC2 temporal. `source_ami_filter` resuelve el AMI base más reciente de Amazon Linux 2023 x86_64.
- **`build { sources = [...] }`**: qué sources construye (puedes tener varios para multi-arch o multi-cloud).
- **`provisioner "ansible"`**: Packer abre SSH a la EC2 temporal y corre `ansible-playbook` **desde el host de Packer** (no dentro de la VM) apuntando a esa EC2.
- **`post-processor "manifest"`**: deja un `packer-manifest.json` con el `ami_id` producido, consumible por el pipeline.

## 4. El playbook

`playbook.yml`:

```yaml
---
- name: Bake webapp AMI
  hosts: all
  become: true
  gather_facts: true

  vars:
    nginx_port: 80
    app_user: webapp

  tasks:
    - name: Install base packages
      ansible.builtin.dnf:
        name:
          - nginx
          - python3
          - amazon-cloudwatch-agent
        state: present

    - name: Create service user
      ansible.builtin.user:
        name: "{{ app_user }}"
        system: true
        shell: /sbin/nologin

    - name: Deploy nginx config
      ansible.builtin.copy:
        src: files/nginx.conf
        dest: /etc/nginx/nginx.conf
        owner: root
        group: root
        mode: "0644"

    - name: Enable nginx service (will start on first boot)
      ansible.builtin.systemd:
        name: nginx
        enabled: true

    - name: Clean dnf cache (keep AMI small)
      ansible.builtin.command: dnf clean all
      changed_when: false
```

Notas:

- `hosts: all` — Packer pasa un inventario de un solo host (la EC2 temporal).
- `enabled: true` sin `state: started` — queremos que nginx arranque **cuando la AMI se instancie**, no durante el build (si arrancara con el ssh abierto podría escribir cosas al disco que ensucien la imagen).
- `dnf clean all` al final — reduce tamaño de la AMI quitando metadata de paquetes.

## 5. El flujo end-to-end

```bash
# 1. Inicializa Packer (descarga plugins). Una vez.
cd packer/
packer init .

# 2. Valida sintaxis y referencias (local, no requiere credenciales AWS).
packer validate -var "app_version=1.2.3" .

# 3. Build (requiere credenciales AWS; lanza EC2 real).
packer build -var "app_version=1.2.3" .

# 4. Terraform consume el ami_id del manifest.
AMI_ID=$(jq -r '.builds[-1].artifact_id' packer-manifest.json | cut -d: -f2)
cd ../infra/
terraform apply -var "ami_id=$AMI_ID"
```

En CI (GitHub Actions):

```yaml
jobs:
  bake-and-deploy:
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-packer@main
      - name: Packer init
        run: packer init ./packer
      - name: Packer validate
        run: packer validate -var "app_version=${{ github.sha }}" ./packer
      - name: Packer build
        run: packer build -var "app_version=${{ github.sha }}" ./packer
      - name: Extract AMI id
        id: ami
        run: echo "ami_id=$(jq -r '.builds[-1].artifact_id' packer/packer-manifest.json | cut -d: -f2)" >> $GITHUB_OUTPUT
      - name: Terraform apply
        run: terraform apply -auto-approve -var "ami_id=${{ steps.ami.outputs.ami_id }}"
        working-directory: ./infra
```

## 6. Alternativa — `ansible-local`

Si no quieres que la máquina de Packer tenga Ansible instalado (por ejemplo, un runner de CI minimalista), puedes usar `provisioner "ansible-local"`. Packer sube los archivos al host temporal y corre `ansible-playbook` **dentro**. Requiere Python + ansible-core instalados en el AMI base (hay que añadir una task `dnf install python3-pip ansible-core` al principio o usar un AMI base que ya lo lleve).

## 7. Qué no horneas

- **Secretos** (API keys, DB passwords, certs). Van vía user-data + Secrets Manager / Parameter Store al arrancar la instancia.
- **IP / hostname** de la instancia (depende del arranque).
- **Config específica del tenant** si vas a usar la misma AMI para varios tenants (va vía user-data).

Regla práctica: hornea lo que no cambia entre instancias; inyecta en runtime lo que sí.

## 8. Preguntas de autocomprobación

1. Si `source_ami_filter` cambia la AMI base, ¿cómo haces un build reproducible mañana?
2. ¿Por qué `use_proxy = false` en el provisioner? ¿Qué pasaría si no lo pusieras?
3. ¿Qué pasa si tu playbook no es idempotente? ¿Rompe el build de Packer?
4. ¿Cómo haces rollback a la AMI anterior si la nueva despliega mal?
5. Diferencia entre `provisioner "ansible"` y `provisioner "ansible-local"`.
