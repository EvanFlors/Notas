# Lección — Ansible híbrido con Terraform, Packer y AWX/AAP

> Nivel: producción. 5 h. Pre: `ans-04`, `ans-07`, curso Terraform completo, curso Docker.
>
> Esta lección asume que ya escribes playbooks idempotentes, usas roles, y entiendes qué resuelve Terraform. El foco aquí es **cómo encajan** Terraform, Packer y Ansible — y cuándo AWX/AAP aporta.

---

## 1. El problema: ¿dónde empieza cada herramienta?

Un error de principiante es querer resolver todo con una sola herramienta. En infra moderna conviven, como mínimo:

- **Terraform** (o OpenTofu): aprovisiona recursos cloud (VPCs, EC2, RDS, S3, DNS). *Declara* el estado deseado y aplica.
- **Packer**: construye *imágenes* (AMI, GCE image, Docker image, OVA). Hornea software + configuración en una imagen inmutable.
- **Ansible**: configura *hosts existentes*. Push, agentless, SSH. Idempotente cuando se escribe con disciplina.
- **Helm / GitOps (Argo CD / Flux)**: aplica manifiestos de Kubernetes. Reconciliación continua.

El antipatrón habitual: usar Ansible para crear VPCs (puede, pero Terraform lo hace mejor), o usar Terraform para instalar paquetes dentro de una VM (puede con `remote-exec`, pero es frágil), o usar Ansible para desplegar en K8s (puede, pero Helm/Argo lo hacen mejor).

La **regla de oro**: cada herramienta brilla donde el estado que gestiona cambia a su ritmo natural.

| Estado | Cambia cada… | Herramienta |
|--------|--------------|-------------|
| Topología cloud (VPC, subnets, DNS, IAM) | semanas–meses | Terraform |
| Imagen base de la VM (SO + runtime + agent) | semanas | Packer (con Ansible como provisioner) |
| Config de servicio en host long-lived | días | Ansible |
| Manifiesto K8s / Helm chart | horas | Helm + GitOps |
| App code | commits | pipeline de CI/CD |

---

## 2. Patrón 1 — "TF crea → Ansible configura"

### 2.1 Flujo

```
┌──────────────┐    ┌───────────────────┐    ┌──────────────────┐
│  terraform   │ -> │  outputs (IPs,    │ -> │  ansible dynamic │
│    apply     │    │  tags, DNS)       │    │  inventory       │
└──────────────┘    └───────────────────┘    └────────┬─────────┘
                                                      │
                                                      v
                                              ┌──────────────────┐
                                              │ ansible-playbook │
                                              │  site.yml        │
                                              └──────────────────┘
```

Terraform crea 3 EC2 con tag `Role=web`. Ansible usa el plugin `amazon.aws.aws_ec2` con `filters: tag:Role: web` para enumerarlas en tiempo de ejecución y aplicar el playbook.

### 2.2 Ventajas

- **Separación de concerns clara**: TF declara la topología; Ansible declara la configuración.
- **Funciona con hosts long-lived**: una EC2 que vive meses puede ir recibiendo parches, nuevos vhost, nuevos usuarios SSH — todo con Ansible, sin recrear la VM.
- **Legacy**: casi todo lo legacy encaja aquí (bare metal, VMs on-prem, ECS/EKS fuera de alcance).

### 2.3 Desventajas

- **Drift**: alguien hace `ssh` al host y edita `/etc/nginx/nginx.conf` a mano. El próximo apply de Ansible lo revierte (bien) **si** se corre; si nadie lo corre, el host diverge.
- **Dos fuentes de verdad**: el estado está en el `.tfstate` de Terraform **y** en los playbooks de Ansible. Un cambio puede necesitar coordinación.
- **Day-2 ops frágiles**: olvidar correr Ansible tras un `terraform apply` es un bug clásico.

### 2.4 Buenas prácticas

- Inventario **dinámico** (nunca estático) para que coincida siempre con lo que TF creó.
- Tag convencional (`Role`, `Environment`, `App`) usado como filtro del plugin.
- Playbook idempotente **de verdad** (ver `ans-07`): correrlo 2 veces debe dar 0 changes.
- Pipeline único: TF apply **+** Ansible converge en el mismo job de CI, no en dos jobs separados que un humano decide invocar.

---

## 3. Patrón 2 — "Packer + Ansible → AMI → TF usa AMI"

### 3.1 Flujo

```
┌──────────────┐   ┌────────────────┐   ┌─────────────┐   ┌──────────────┐
│  packer      │-->│  Ansible       │-->│  AMI con    │-->│  terraform   │
│  build       │   │  provisioner   │   │  todo       │   │  apply       │
│  (lanza EC2  │   │  (converge     │   │  horneado   │   │  (lanza EC2  │
│  temporal)   │   │  en la EC2     │   │  (snapshot) │   │  usando ese  │
└──────────────┘   │  temporal)     │   └─────────────┘   │  ami_id)     │
                   └────────────────┘                      └──────────────┘
```

Packer:

1. Lanza una EC2 temporal desde una AMI base (Amazon Linux 2023, Ubuntu, etc.).
2. Ejecuta un **provisioner** `ansible` (local → SSH a la EC2 temporal) que aplica el playbook.
3. Hace `aws ec2 create-image`, obtiene el nuevo `ami_id`.
4. Termina la EC2 temporal.

Terraform luego usa ese `ami_id` en su `aws_instance` o `aws_launch_template`. Cada vez que quieras actualizar: construyes una nueva AMI y lanzas instancias nuevas (rolling).

### 3.2 Ventajas

- **Sin drift**: la imagen es inmutable. Nadie `ssh`-ea para editar porque la instancia va a morir en la próxima rotación.
- **Un solo apply es suficiente**: TF arranca la instancia y en segundos está lista. No hay "primero TF, luego Ansible, luego cruza los dedos".
- **Rollback trivial**: la AMI anterior sigue existiendo. Si la nueva falla, lanzas la antigua.
- **Autoscaling-friendly**: nuevas instancias arrancan ya configuradas; no esperan a que Ansible las "despierte".

### 3.3 Desventajas

- **Build time**: construir una AMI tarda minutos (vs segundos de un apply de Ansible en host existente).
- **Config secreta en runtime**: la AMI no puede llevar secretos; estos se inyectan al arrancar (user-data + Secrets Manager / Parameter Store).
- **Discos efímeros**: si tu app guarda estado en disco local, inmutable te duele; necesitas EBS attach-detach o pasar a S3/RDS.

### 3.4 Cuándo migrar al patrón 2

Cuando puedes decir que sí a la mayoría de estas:

- **Las instancias no deberían vivir más de días/semanas** (apps nuevas, autoscaling).
- **Los secretos ya están fuera del repo** (Secrets Manager / Vault).
- **El estado está fuera del disco local** (RDS, S3, Dynamo).
- **Tienes CI que puede correr `packer build`** en minutos (y storage para N AMIs).

Si contestas no a 2 o más: quédate en patrón 1 por ahora, planea migración.

---

## 4. Plantilla Packer HCL2 con provisioner Ansible — anatomía

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

source "amazon-ebs" "al2023" {
  region         = var.region
  instance_type  = "t3.micro"
  ami_name       = "webapp-al2023-{{timestamp}}"
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
      "--extra-vars", "nginx_port=80",
      "-v"
    ]
  }
}
```

Puntos clave:

- `required_plugins`: Packer necesita el plugin `ansible` instalado (`packer init .` lo baja).
- `source "amazon-ebs"`: define la EC2 temporal.
- `provisioner "ansible"`: Packer abre un túnel SSH y corre `ansible-playbook` **desde tu laptop/CI** apuntando al host temporal.
- `use_proxy = false`: evita el proxy local de Packer y conecta directo (más simple).
- `extra_arguments`: cualquier flag extra para `ansible-playbook`.

**Alternativa**: `provisioner "ansible-local"` corre Ansible **dentro** de la VM (requiere Python + ansible-core instalados en la imagen base). Útil cuando no quieres que la máquina de Packer necesite SSH entrante del host temporal.

---

## 5. Inventario dinámico — por qué y cómo

### 5.1 Problema

Si tus EC2 cambian cada semana (autoscaling), mantener `inventories/prod/hosts.yml` a mano es un bug permanente. Peor: alguien lo olvida, un nuevo host no recibe el apply, y descubres el día del incidente que un host "no tenía" el fix.

### 5.2 Solución

Un *inventory plugin* consulta la API de la nube en tiempo de ejecución. Para AWS, el plugin oficial vive en la collection `amazon.aws`.

`inventory/aws_ec2.yml`:

```yaml
plugin: amazon.aws.aws_ec2
regions:
  - eu-west-1
filters:
  tag:Environment: production
  tag:ManagedBy: ansible
  instance-state-name: running
keyed_groups:
  - key: tags.Role
    prefix: role
hostnames:
  - private-ip-address
compose:
  ansible_host: private_ip_address
```

Uso:

```bash
ansible-inventory -i inventory/aws_ec2.yml --graph
ansible-playbook -i inventory/aws_ec2.yml site.yml
```

Esto produce grupos tipo `role_web`, `role_db` automáticamente. El playbook solo tiene que decir `hosts: role_web`.

### 5.3 Equivalentes

- GCP: `google.cloud.gcp_compute` (de la collection `google.cloud`).
- Azure: `azure.azcollection.azure_rm`.
- Kubernetes: `kubernetes.core.k8s` (menos usado — para K8s hay mejores herramientas).

---

## 6. AWX / AAP — ¿qué aportan sobre `ansible-playbook`?

### 6.1 Contexto

- **AWX**: proyecto OSS upstream, mantenido por Red Hat y la comunidad. Despliega sobre Kubernetes (operator oficial).
- **AAP** (*Ansible Automation Platform*): la versión comercial soportada por Red Hat. Incluye AWX + Automation Hub + content certificado + soporte. Pricing por nodo gestionado.

Ambos exponen la **misma interfaz operativa**: un backoffice web para orquestar Ansible a escala.

### 6.2 Qué aportan

1. **Inventarios compartidos** entre equipos (en vez de un `hosts.yml` por repo).
2. **RBAC fino**: "team X puede correr el job `deploy-nginx` sobre el inventario `prod/web`, pero no sobre `prod/db`".
3. **Credenciales centralizadas**: SSH keys, cloud credentials, vault passwords — guardados en AWX, nunca en el repo ni en la máquina del operador.
4. **Job templates**: encapsulan "qué playbook + qué inventario + qué extra-vars + qué credenciales" en un botón reusable.
5. **Surveys**: formulario web que recoge inputs (dropdowns, text) que el job template inyecta como extra-vars. Útil para que SRE no toque YAML.
6. **Workflow templates**: encadenan N job templates con lógica (éxito → siguiente; fallo → notificar y parar).
7. **Scheduling**: cron en la UI para corridas periódicas (compliance, patching, housekeeping).
8. **Notifications**: Slack / email / webhook al terminar un job.
9. **Audit log**: quién corrió qué contra qué, cuándo, con qué resultado — fundamental para compliance.
10. **Instance groups / execution environments**: aislar ejecuciones por entorno (contenedores EE con collections específicas).

### 6.3 Cuándo vale la pena

- Equipo de 20+ personas que necesitan correr playbooks (no solo DevOps).
- Múltiples inventarios y credenciales con RBAC real.
- Requisito de audit log formal (SOX, PCI, HIPAA).
- Necesidad de delegar operaciones a SRE / Soporte / NOC vía surveys.

### 6.4 Cuándo NO

- Equipo pequeño con 1 playbook crítico — `ansible-playbook` desde una CI basta (y es más barato).
- Todas las workloads en K8s — tienes mejores herramientas de orquestación.
- No tienes capacidad de mantener un cluster K8s para AWX (es un sistema no trivial).

---

## 7. Event-Driven Ansible (EDA)

### 7.1 Qué es

Un **rulebook** declara: *"cuando llegue este evento, dispara este playbook"*. Las fuentes de eventos son plugins: webhook HTTP, Kafka, Alertmanager, cloudevents, Journald, archivo plano, etc.

Ejemplo de rulebook:

```yaml
---
- name: Restart web on alert
  hosts: all
  sources:
    - ansible.eda.webhook:
        host: 0.0.0.0
        port: 5000
  rules:
    - name: Payload says restart
      condition: event.payload.action == "restart_web"
      action:
        run_playbook:
          name: playbooks/restart_web.yml
```

Lanzar: `ansible-rulebook --rulebook rulebook.yml -i inventory.yml`.

### 7.2 Casos típicos

- **Alertmanager → remediate**: la alerta "disk full on web-03" dispara un playbook de limpieza + notifica.
- **GitHub webhook → deploy**: push a `main` dispara un playbook de despliegue.
- **CloudTrail / Kafka de auditoría → responde a cambios no autorizados**: alguien editó una IAM policy fuera de Terraform; un rulebook la revierte y notifica.

### 7.3 Cuándo vale

Automatizar runbooks que hoy son correos de alerta leídos por humanos. El valor viene de **cerrar el loop sin humano** en el camino crítico de respuesta.

---

## 8. Boundaries — qué NO hacer con Ansible

| Caso | Mejor herramienta | Por qué |
|------|-------------------|---------|
| Crear una VPC, subnets, RDS, S3 | Terraform | Declarativo nativo del cloud; `terraform state` como fuente de verdad. |
| Instalar nginx dentro del contenedor Docker | `Dockerfile` | La imagen es la unidad de distribución; Ansible dentro de un build de imagen es un smell. |
| Desplegar app en Kubernetes | Helm + Argo CD / Flux | Reconciliación continua, rollback nativo, drift detection. |
| Rotar certificados ACM | Terraform + CertManager | Automatización nativa del servicio. |
| Config de aplicación por entorno | Variables de entorno + secret manager | Ansible puede pero añade una capa innecesaria para 12-factor apps. |

Dónde Ansible **sí** brilla:

- Day-2 ops sobre hosts long-lived (patching, config de servicios, usuarios).
- Bare metal / network devices (donde no hay API cloud).
- Bootstrap de nodos (Linux base + kubeadm + join cluster).
- Incident response automatizado (vía EDA).
- Scripts administrativos reproducibles (en vez de bash sueltos).

---

## 9. Resumen operativo

- **Pattern 1 (TF + Ansible)**: por defecto para legacy, host long-lived, bare metal.
- **Pattern 2 (Packer + Ansible)**: por defecto para workloads nuevas, autoscaling, blast radius bajo.
- **AWX/AAP**: aporta cuando el consumo de Ansible pasa de "equipo de 3" a "equipo de 30+ con RBAC real".
- **EDA**: aporta cuando quieres cerrar el loop alerta → remediación sin humano.
- **No forces Ansible** donde Terraform / Helm / GitOps resuelven mejor. El error típico es "tengo martillo, todo es clavo".

En el próximo módulo (`ans-10`) formalizamos esto como *contrato de plataforma*: qué puede y qué no puede hacerse con Ansible en la organización.
