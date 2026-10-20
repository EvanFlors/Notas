# REFERENCE — ans-10-01-platform-contract-adr

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

---

# ADR 010 — Contrato de plataforma Ansible

## Estado

Propuesto (Fase 3). Objetivo: ser Aceptado tras revisión de platform-sre + security + un tech lead de un consumer team, y publicado como `CONTRIBUTING.md` del repo `ops/ansible` en Fase 4.

## Contexto

La organización tiene un stack mixto:

- 25 microservicios en EKS gestionados con Helm + Argo CD.
- 15 VMs long-lived (BI, ETL antiguo, bastion, 2 runners self-hosted de GHA).
- Infraestructura cloud AWS en Terraform (VPC, RDS, S3, IAM, EKS).
- Rack bare-metal en colo con 8 servidores (datalake) y 12 switches Cisco Nexus.
- Secrets en AWS Secrets Manager con rotación programada.

El repo `ops/ansible` acumula 70 playbooks sin owners claros. Dos de ellos despliegan a EKS "cuando Argo CD no responde", lo que esconde un problema de confianza en el GitOps y crea drift (Argo revierte parcial, nadie se entera). Un RFC reciente propone **usar Ansible para desplegar una app NestJS a Kubernetes**; sin un documento citable, cada propuesta de este tipo abre una discusión de 2 semanas. Este ADR fija el contrato en una página para cerrar esas discusiones por default.

## Decisión

### 1. Dominios donde Ansible es la herramienta por defecto

| # | Dominio | Por qué |
|---|---------|---------|
| 1 | Day-2 ops sobre VMs long-lived (patching OOB, cert rotation, cambio puntual de sysctl) | Imperativo, ocasional, sobre hosts que no se rotan — mejor que reconstruir imagen. |
| 2 | Bootstrap de nodos (kubeadm bare-metal, control planes self-managed) | Instalar containerd/kubelet, generar join token, montar etcd — terreno Ansible. |
| 3 | Equipos de red (Cisco Nexus, Arista si aparece) | `cisco.ios`, `arista.eos` son maduras; flujos imperativos encajan mal con TF. |
| 4 | Bare metal (datalake, hipervisores on-prem) | Sin API cloud; SSH/WinRM/REST + collections `dellemc.*`, `community.vmware`. |
| 5 | Incident response (runbooks ejecutables) | Playbook con `--check`/`--diff`, tags por paso; auditable y versionado. |
| 6 | Hardening CIS/STIG | `ansible-lockdown.rhel9_cis`, `ubuntu2404_cis`. |
| 7 | Ansible como provisioner de Packer durante el build de AMIs | Hornear = Packer; configurar durante el horneado = Ansible. |

### 2. Dominios donde Ansible NO se usa (anti-patrones duros)

| # | Caso | Herramienta correcta |
|---|------|----------------------|
| 1 | Desplegar o actualizar apps en Kubernetes | Helm + Argo CD / Flux |
| 2 | Aprovisionamiento cloud (VPC, RDS, S3, IAM, EKS) | Terraform / OpenTofu |
| 3 | Configuración interna de contenedores | Dockerfile multi-stage o Packer con builder docker |
| 4 | Reconciliación continua de CRDs propios | Operador K8s (Operator SDK, Kubebuilder) |
| 5 | Rotación de secretos aplicativos en runtime | AWS Secrets Manager scheduled rotation + External Secrets Operator |
| 6 | Service mesh config dinámica | Istio / Linkerd via sus CRDs |
| 7 | Build de software (compilar binarios) | CI (GHA, GitLab CI) |

### 3. Herramientas alternativas por dominio (tabla citable)

```text
+-----------------------------------------+----------------------+-------------------+
| caso                                    | herramienta elegida  | rechazada         |
+-----------------------------------------+----------------------+-------------------+
| Deploy microservicio a EKS              | Helm + Argo CD       | Ansible (no)      |
| Crear VPC + RDS + IAM                   | Terraform            | Ansible (no)      |
| Hornear AMI base nginx + agent          | Packer + Ansible     | Ansible solo      |
| Cert rotation en 50 bastiones live      | Ansible              | Rotar AMI (over)  |
| Rotar password RDS                      | Secrets Manager      | Cron Ansible      |
| Bootstrap kubeadm on-prem               | Ansible              | Cloud-init solo   |
| Cambiar VLAN en 400 puertos Cisco       | Ansible (cisco.ios)  | TF cisco provider |
| Hardening CIS en fleet mixta            | Ansible-lockdown     | Scripts bash      |
| Reconciliar CRD propio                  | Operador K8s         | Ansible cron      |
| Auto-remediate "disk full" alert        | Ansible EDA          | Cron de check     |
+-----------------------------------------+----------------------+-------------------+
```

### 4. Immutable-first y rol de Packer

Para cualquier workload cloud (ASG, launch template, EKS node groups self-managed), la vía por defecto es:

1. **Packer** construye la AMI, con Ansible como provisioner.
2. **Terraform** usa la AMI (`data.aws_ami`).
3. Cambios de config → nueva AMI → rolling de la ASG → viejos nodos mueren.
4. **Ansible no toca los hosts cloud en producción.**

Patrón mutable (Ansible sobre long-lived) queda reservado a: bare metal, hardware raro, legacy no reconstruible, Day-2 fuera del happy path (filas 1, 4, 5 de §1).

### 5. Ownership, review y CI

- **CODEOWNERS por path** en `ops/ansible/`: `playbooks/network/* @network-platform`, `roles/postgres/* @data-platform`, etc. Sin owner = no se mergea.
- **Review obligatorio**: 1 reviewer humano + `ansible-lint` + `molecule test` en CI.
- **CI matrix**: `ansible-core` (latest + N-1), distros según el target (Ubuntu 24.04, Rocky 9, Debian 12 al menos).
- **Versionado SemVer** para roles compartidos; `requirements.yml` del consumidor fija versión.
- **CHANGELOG.md** por role vía `antsibull-changelog`.

### 6. Control plane operacional

- **AWX** (OSS, vía `awx-operator` en nuestro EKS de tools) como control plane: inventarios, job templates, workflow templates, approval nodes, RBAC, surveys, notificaciones Slack/PagerDuty.
- **Event-Driven Ansible** (`ansible-rulebook`): fuentes `ansible.eda.alertmanager` y `ansible.eda.webhook`, para auto-remediation acotada (disk full, pod OOM recurrente). No reemplaza operadores K8s.
- **Logs al SIEM** (Splunk) vía Fluent Bit sidecar; eventos de audit retenidos 1 año.

### 7. Excepciones y proceso para solicitarlas

Un equipo que quiera usar Ansible en un dominio "no" debe:

1. Abrir un **RFC** en `rfcs/` describiendo caso, alternativa descartada y por qué.
2. Aprobación de **platform-sre** + un **tech lead** externo al equipo que lo propone.
3. **Sunset date obligatorio** (6 meses máximo) con migración al dominio correcto.
4. Entry en el **registro de excepciones** del contrato.

Las excepciones son numerables y revisadas cada trimestre. Si se acumulan ≥5 en el mismo dominio, se reabre el contrato.

## Consecuencias

### Positivas

- Discusiones de "¿Ansible o X?" se resuelven en el PR con un link al contrato (≤ 5 min).
- Reducción esperada de drift: eliminar los 2 playbooks que deployan a EKS cierra la ambigüedad con Argo CD.
- Nuevos equipos tienen un onramp claro: leen el contrato en el día 1.
- Platform-sre puede medir deriva (playbooks fuera del dominio = métrica trimestral).

### Negativas

- Overhead inicial de review para marcar los 70 playbooks existentes (dentro / fuera / deprecar).
- Perdemos un escape rápido: cuando Argo CD falla, no "parcheamos" con Ansible — tenemos que arreglar Argo CD. Beneficio neto, pero cambio cultural.
- Equipos con sesgo "Ansible resuelve todo" se sentirán limitados y pedirán excepciones.

## Alternativas descartadas

### Alt A — "Libertad total, cada equipo elige su herramienta"

- **Por qué no**: produce el estado actual (70 playbooks sin dueño, dos despliegues K8s con Ansible, drift). Sin contrato, cada equipo re-descubre el mismo trade-off cada seis meses. La libertad individual degrada la mantenibilidad global.

### Alt B — "Prohibir Ansible por completo, migrar todo a Terraform + operadores K8s"

- **Por qué no**: ignora Day-2 sobre bare metal y equipos de red, donde Ansible no tiene competidor razonable. También condena a reescribir hardening CIS en una herramienta menos adecuada (Chef InSpec, scripts bash). Es la sobre-reacción opuesta al problema.

### Alt C — "Mantener Ansible como herramienta universal, limitar via lint rules"

- **Por qué no**: las lint rules son fáciles de evadir y no capturan la decisión arquitectónica (p. ej. no detectan "este playbook deploya a K8s" si se usa el módulo `kubernetes.core.k8s`). El contrato humano citable es más eficaz y más barato que una suite de reglas.

---

## Fase 2 (previsible en 12–18 meses)

- Migrar los 15 VMs long-lived restantes a inmutable (AMIs + ASG) si se puede, dejando bare metal como único dominio mutable.
- Evaluar **Red Hat AAP 2.x** si crecemos a >10 equipos consumer; AWX OSS sigue bien hasta ~5 equipos.
- Adoptar **ansible-navigator** y **execution environments** (imágenes OCI con collections pinned) para reproducibilidad entre runners y laptops.
