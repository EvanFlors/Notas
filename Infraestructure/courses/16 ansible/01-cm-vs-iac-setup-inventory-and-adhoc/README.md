# ans-01 — CM vs IaC, setup, inventory y ad-hoc

## Identificación

- **ID:** `ans-01-cm-vs-iac-setup-inventory-and-adhoc`
- **Curso:** `ansible`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** curso **terraform** ≥ Nivel 1 (para contrastar CM vs IaC).

## Objetivo

Interiorizar la frontera entre **Configuration Management** (lo que hace Ansible: configurar hosts que *ya existen*) e **Infrastructure as Code** (lo que hace Terraform: *crear* los hosts). Al terminar deberías saber instalar Ansible, modelar un **inventory** estático y dinámico, y disparar comandos **ad-hoc** contra un grupo sin escribir un playbook.

## Alcance

Este módulo cubre:

- La diferencia entre **CM** (Ansible, Chef, Puppet, Salt) e **IaC** (Terraform, Pulumi, CloudFormation) con ejemplos concretos.
- El modelo de ejecución de Ansible: **push + agentless + SSH**, serialización de módulos Python en el target.
- Instalación recomendada (`pipx install ansible`), verificación con `ansible --version` (ansible-core + collections).
- **Inventory** estático en formatos YAML (`hosts.yml`) e INI (`hosts.ini`): grupos, children, `group_vars`, `host_vars`.
- **Inventory dinámico** vía plugins oficiales (`amazon.aws.aws_ec2`, `google.cloud.gcp_compute`) y vía *scripts* (contrato JSON heredado).
- Herramientas: `ansible-inventory --list`, `ansible all -m ping`, `ansible <grupo> -m shell -a "uptime"`.
- Variables de conexión clave: `ansible_user`, `ansible_host`, `ansible_ssh_private_key_file`, `ansible_python_interpreter`.

Lo que **no** cubre (siguientes módulos):

- Playbooks, módulos idempotentes y handlers → `ans-02`.
- Variables, facts, Jinja2 y templates → `ans-03`.
- Roles, collections y vault → `ans-04`, `ans-05`, `ans-06`.

El módulo es **100 % local**: usa `localhost` como managed node y, opcionalmente, 2–3 contenedores `ubuntu:22.04` con `sshd` como *managed nodes* adicionales. No requiere cuenta AWS activa para la actividad 02 (el inventario dinámico se practica contra un *mock* y un fichero de configuración plugin).

## Materiales

- **`theory/lesson.md`** — lección profunda (10 secciones).
- **`examples/`** — tres ejemplos de lectura y análisis:
  - `01-first-ping-with-ssh/` — primer `ansible -m ping` contra `localhost` explicando qué pasa por detrás.
  - `02-inventory-yaml-vs-ini/` — mismo inventario en los dos formatos, cuándo preferir cada uno.
  - `03-ec2-dynamic-inventory/` — fichero `aws_ec2.yml` del plugin `amazon.aws.aws_ec2` anotado.
- **`activities/`** — dos actividades independientes:
  - `01-connect-to-vms/` (guiada, beginner) — escribir un inventario YAML con un grupo `managed`, correr `ping` y `shell -a "uptime"` contra `localhost` (o contra contenedores Docker).
  - `02-dynamic-inventory-ec2/` (independiente, intermediate) — redactar un `aws_ec2.yml` del plugin oficial y un *script* dinámico mínimo que respete el contrato JSON de Ansible; validar sin AWS real.
- **`resources/links.md`** — documentación oficial y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar en 2 frases cuándo usar Ansible y cuándo Terraform para un escenario dado. Describir el flujo push-agentless-SSH. |
| Operativa | Instalar `ansible` con `pipx`, escribir un `hosts.yml` con grupos y `group_vars`, correr `ansible all -m ping`. |
| Arquitectónica | Elegir inventario estático vs dinámico según tamaño/volatilidad de la flota. Mapear qué variables de conexión usar según el entorno (SSH key, user, interpreter). |

## Criterios de evaluación

- Dado un escenario ("instalar Grafana en 50 VMs ya existentes"), justificar Ansible vs Terraform vs Docker.
- Leer un `hosts.yml` y describir qué hosts hereda cada grupo.
- Explicar por qué `ping` de Ansible **no** es ICMP.
- Entregar las dos actividades con sus validadores en verde.

## Entregables

- Un `inventory.yml` con al menos 2 hosts y 1 grupo, más capturas de `ansible-inventory --list` y `ansible all -m ping` (actividad 01).
- Un `aws_ec2.yml` sintácticamente válido y un *script* dinámico que emite el JSON esperado por Ansible (actividad 02).

## Costos

**Ninguno.** Todo se ejecuta localmente. Si en una fase posterior decides correr Ansible contra EC2 real, el coste será el de las instancias (t3.micro ~$0.01/h en eu-west-1).

## Siguiente módulo

→ `ans-02-playbooks-plays-tasks-modules-handlers` — pasar de ad-hoc a playbooks reproducibles con módulos idempotentes y handlers.
