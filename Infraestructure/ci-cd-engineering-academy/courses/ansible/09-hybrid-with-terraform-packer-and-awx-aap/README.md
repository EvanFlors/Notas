# ans-09 — Ansible híbrido con Terraform, Packer y AWX/AAP

## Identificación

- **ID:** `ans-09-hybrid-with-terraform-packer-and-awx-aap`
- **Curso:** `ansible`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `ans-04` (roles), `ans-07` (idempotencia y patrones avanzados), curso **terraform** completo, curso **docker**.

## Objetivo

Interiorizar cómo combinar Ansible con **Terraform** y **Packer** sin pelearse con ninguno, y entender el valor (y los límites) de **AWX / Ansible Automation Platform** como orquestador empresarial. Al terminar deberías poder decidir — en papel — cuándo quedarse en el patrón *mutable* (TF crea → Ansible configura) y cuándo migrar al patrón *immutable* (Packer + Ansible → AMI → TF usa AMI), y defender la elección frente a un equipo.

## Alcance

Este módulo cubre:

- **Patrón 1 — "TF crea → Ansible configura"**: Terraform provisiona EC2 / VMs, exporta outputs (IPs, tags) y Ansible converge el host vía inventario dinámico (`amazon.aws.aws_ec2`, `google.cloud.gcp_compute`). Convive con hosts long-lived y legacy.
- **Patrón 2 — "Packer + Ansible → imagen inmutable"**: Packer construye una AMI (o imagen GCE / Azure) usando Ansible como *provisioner*; Terraform consume el `ami_id` resultante. Elimina drift por construcción.
- **Criterios de decisión** entre ambos patrones (hosts long-lived vs rotación, legacy vs greenfield, velocidad de iteración, blast radius).
- **AWX / AAP** como panel central: UI, inventarios compartidos, RBAC, surveys, workflow templates, notifications, scheduling. Qué aporta sobre `ansible-playbook` desde una laptop o CI.
- **Event-Driven Ansible** (EDA) como extensión reactiva: webhook / Kafka / Alertmanager → playbook → runbook automatizado.
- **Límites**: dónde Ansible pierde frente a Helm / GitOps (apps en K8s) o frente a servicios cloud nativos.

Lo que **no** cubre (se verá después):

- Operar Ansible como contrato de plataforma, boundaries con TF/K8s/GitOps y deprecation de playbooks → `ans-10`.
- Instalación productiva de AAP en Kubernetes/OpenShift (es un ejercicio operativo específico).
- Terraform y Packer en profundidad (asumidos del curso Terraform y de Packer; aquí solo se usa lo necesario).

Este módulo es **mayoritariamente conceptual + ADR + laboratorio local**. **No** se provisiona nada en una cuenta cloud real. Las validaciones son todas locales: `terraform validate`, `packer validate`, `ansible-playbook --syntax-check` cuando las herramientas estén instaladas; si falta alguna, el validador la marca como **SKIP** y sigue.

## Materiales

- **`theory/lesson.md`** — lección profunda con secciones sobre patrones híbridos, Packer+Ansible, AWX/AAP, EDA y boundaries.
- **`examples/`** — tres ejemplos demostrativos (lectura y análisis):
  - `01-tf-outputs-to-ansible-inventory/` — flujo *outputs → inventory → converge* usando el plugin `amazon.aws.aws_ec2` con filtros por tag.
  - `02-packer-ansible-ami/` — plantilla Packer HCL2 con `ansible` como provisioner, mostrando cómo se hornea el estado en la imagen.
  - `03-event-driven-ansible-webhook/` — walkthrough de un *rulebook* EDA que reacciona a un webhook y lanza un playbook. Incluye paseo por AWX/AAP (project → inventory → job template → workflow → survey).
- **`activities/`** — dos actividades:
  - `01-build-ami-with-packer-and-ansible/` (guided-lab) — escribir una plantilla Packer HCL2 que use un playbook Ansible como provisioner para hornear nginx + usuario de servicio en una AMI base de Amazon Linux 2023. Validación local con `packer validate` y `ansible-playbook --syntax-check`.
  - `02-tf-ansible-or-packer-ansible-adr/` (architecture, independiente) — ADR eligiendo *mutable* vs *immutable* para 3 workloads dados y defendiéndolo con un cuadro de trade-offs.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar diferencia entre patrón mutable y patrón immutable; por qué Packer baja el drift; qué aporta AWX/AAP sobre `ansible-playbook` desde una CI. |
| Operativa (local) | Escribir una plantilla Packer HCL2 con provisioner Ansible que pase `packer validate`; escribir el playbook `--syntax-check` limpio; declarar inventario dinámico con `amazon.aws.aws_ec2`. |
| Arquitectónica | Decidir *mutable vs immutable* por workload; justificar cuándo AWX/AAP vale su coste; dibujar el flujo *outputs TF → inventory → converge* y el flujo *Packer → AMI → TF*. |

## Criterios de evaluación

- Dada una lista de 3 workloads (p. ej. *legacy monolith on-prem*, *API nueva en EC2*, *API en EKS*), elegir mutable vs immutable y defenderlo con 3+ criterios.
- Leer una plantilla Packer HCL2 y señalar `source`, `build`, `provisioner "ansible"` y los campos obligatorios (`playbook_file`, `user`, `ssh_authorized_key_file` si aplica).
- Explicar por qué el *inventory dinámico* es preferible a mantener un `hosts.yml` cuando TF crea/destruye instancias.
- Nombrar al menos 3 capacidades que AWX/AAP añade sobre `ansible-playbook` desde la laptop.
- Entregar las dos actividades con sus validadores locales en verde (o SKIP justificado si falta una herramienta).

## Entregables

- **Plantilla Packer + playbook Ansible** validados localmente (sale de la actividad `01`).
- **ADR** `ADR-MUTABLE-VS-IMMUTABLE.md` eligiendo patrón por workload (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos HCL/YAML/Markdown. No se requiere cuenta AWS activa ni se construyen AMIs reales. Si en una fase posterior decides lanzar el flujo contra una cuenta:

- **Packer** build de una AMI: pocos céntimos por build (una EC2 `t3.micro` arrancada por minutos y luego terminada; snapshot EBS persistente hasta que lo borras).
- **Terraform** apply: cuesta lo que cueste la infra que levantes (en este módulo, hipotéticamente, una EC2 pequeña).
- **AWX** (OSS): gratis el software; cuesta el cluster Kubernetes donde corra.
- **AAP** (Red Hat): licencia comercial — verificar pricing vigente con Red Hat.

Verificar precios actuales en Fase 4 antes de aprovisionar.

## Siguiente módulo

→ `ans-10-platform-patterns-when-ansible-when-not` — operar Ansible como parte de la plataforma, con boundaries explícitas frente a Terraform, K8s/Helm y GitOps.
