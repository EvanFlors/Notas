# ans-10 — Patrones de plataforma: cuándo Ansible y cuándo no

## Identificación

- **ID:** `ans-10-platform-patterns-when-ansible-when-not`
- **Curso:** `ansible`
- **Nivel:** producción
- **Duración estimada:** 4 h
- **Prerrequisitos:** `ans-05` (collections), `ans-06` (vault/secretos), `ans-08` (testing/Molecule), `ans-09` (hybrid con TF/Packer/AWX).

## Objetivo

Cerrar el curso con criterio de plataforma: saber **dónde Ansible aporta y dónde estorba** en un stack moderno (contenedores, Kubernetes, cloud managed, GitOps), y traducir ese criterio en un **contrato de plataforma** publicable y defendible frente a equipos que quieran usar Ansible fuera de su zona de valor.

No se aprende sintaxis nueva: se consolidan decisiones. El módulo es **síntesis de capstone**: define los *boundaries* del dominio Ansible en la organización y los planes de deprecación de playbooks que ya no son el camino correcto.

## Alcance

Este módulo cubre:

- **Cuándo Ansible aporta valor**: Day-2 ops sobre hosts long-lived, bootstrap de nodos (kubeadm, control planes self-managed), bare metal, equipos de red (Arista EOS, Cisco IOS XR, Juniper Junos), incident response reproducible, compliance/CIS hardening sobre fleet heterogénea.
- **Cuándo *no* usar Ansible**: apps que corren en Kubernetes (usar Helm + Argo CD / Flux), aprovisionamiento cloud (Terraform / OpenTofu / Pulumi), configuración de contenedores (hornear en la imagen con Packer o buildkit multi-stage), reconciliación continua (operadores K8s, no cron de `ansible-playbook`).
- **Inventory dinámico a escala**: plugins `amazon.aws.aws_ec2`, `google.cloud.gcp_compute`, `azure.azcollection.azure_rm`; cuidado con queries lentas, caching (`cache_plugin: jsonfile`), filtros por tag/label; límites prácticos (>10k hosts) y alternativas (constructed inventory, split por región).
- **Mindset immutable-first**: Packer + AMI/golden image es la vía por defecto en 2026; mutable con disciplina solo cuando no hay alternativa (legacy, hardware).
- **Ownership como código**: CODEOWNERS por role/playbook, versionado SemVer, review obligatorio en PR, lint + Molecule en CI.
- **Seguridad operativa**: SSH key management con workload identity (OIDC + bastion efímero, Teleport, Boundary) en lugar de llaves largas; HSM/Yubikey para operadores humanos; `ansible-vault` solo como última línea, no como fuente de verdad.
- **Auditoría**: logs de AWX/AAP, integración con el SIEM, correlación con PagerDuty/Opsgenie para incidentes.
- **Deprecation path**: cuándo retirar un playbook, a qué migrar, cómo comunicar sin romper equipos consumidores.

Lo que **no** cubre (se asumió en módulos previos):

- Sintaxis de playbooks, roles o Molecule (ver `ans-02`, `ans-04`, `ans-08`).
- Integración concreta con Terraform/Packer (ver `ans-09`).
- Secretos operacionales (ver `ans-06`).

Este módulo es **casi íntegramente conceptual + ADR**. No se despliega infraestructura real. El entregable es un **contrato de plataforma** escrito y un **plan de deprecación** auditados por el validador estructural.

## Materiales

- **`theory/lesson.md`** — lección profunda con 11 secciones y una matriz de decisión.
- **`examples/`** — tres ejemplos de lectura (no ejecución):
  - `01-ansible-boundaries-matrix/` — matriz "qué sí / qué no" en una tabla auditable.
  - `02-dynamic-inventory-at-scale/` — anatomía de un `aws_ec2.yml` con caching y filtros, y por qué degrada en orgs grandes.
  - `03-awx-workflow-template/` — descripción YAML comentada de un workflow template de AWX con approval node y RBAC.
- **`activities/`** — dos actividades **independientes** entre sí (ambas ADR-style):
  - `01-platform-contract-adr/` — redactar el "contrato Ansible" de la organización: boundaries, dominios, excepciones, deprecation posture.
  - `02-deprecation-plan/` — plan de deprecación para un playbook heredado que ya pertenece a otro paradigma, con fechas, owners y migration path.
- **`resources/links.md`** — referencias oficiales (ansible-core, Red Hat AAP, Event-Driven Ansible, GitOps toolchain).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Enumerar 5 dominios donde Ansible gana y 5 donde pierde frente a herramientas cloud-native, sin consultar notas. |
| Operativa (sin infra) | Escribir un contrato de plataforma de 1 página que un tech lead ajeno pueda citar en code review. |
| Arquitectónica | Justificar en 2 minutos por qué un playbook de "deploy a EKS" es un anti-patrón y proponer el reemplazo. |
| Comunicación | Redactar un plan de deprecación con comunicación a stakeholders, migración por fases y criterios de rollback. |

## Criterios de evaluación

- Dado un caso de uso (p. ej. "configurar certificados en 400 switches Cisco"), elige la herramienta correcta y la defiende contra una alternativa plausible.
- Lee un repositorio con 20 playbooks y clasifica cuáles pertenecen al dominio Ansible y cuáles son candidatos a deprecación.
- Diseña el contrato de plataforma de una org pequeña y lo publica como ADR revisable.
- Produce un plan de deprecación con hitos, owners y canary de corte.

## Entregables

- **ADR** `ADR-ANSIBLE-CONTRACT.md` — contrato de plataforma Ansible (sale de la actividad 01).
- **ADR** `ADR-DEPRECATION-PLAN.md` — plan de deprecación de un playbook heredado (sale de la actividad 02).

## Costos

**Ninguno.** Todo el módulo es texto. No se requiere control plane de AWX ni cuenta cloud. Si en una fase posterior decides materializar el contrato:

- **AWX** (OSS): gratis; su operación en Kubernetes (via `awx-operator`) sí cuesta cómputo.
- **Red Hat AAP** 2.x: licencia comercial por nodo gestionado; típicamente adoptado por orgs con soporte Red Hat.
- **Event-Driven Ansible**: GA; disponible OSS (`ansible-rulebook`) y en AAP.

## Siguiente paso

Fin del curso Ansible. Continúa con el capstone del programa, donde este contrato se materializa junto a los contratos de Terraform (`tf-*`), Docker/K8s y DevSecOps.
