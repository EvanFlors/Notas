# Starter — ans-10-01-platform-contract-adr

Esta actividad es **independiente**: no hay código ejecutable. El entregable es un ADR Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo y revisa los tres `examples/` del módulo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/ans-10-contract
   cd /tmp/ans-10-contract
   ```
3. Crea `ADR-ANSIBLE-CONTRACT.md` con las 6 secciones ADR y el contenido mínimo exigido por el validador.
4. Valida:
   ```bash
   bash <ruta-repo>/courses/ansible/10-platform-patterns-when-ansible-when-not/activities/01-platform-contract-adr/tests/validate.sh /tmp/ans-10-contract
   ```
5. Compara con `../solution/REFERENCE.md`.

> El validador comprueba estructura, no corrección semántica. Esta la revisas tú contra la referencia.

## Plantilla sugerida

```markdown
# ADR 010 — Contrato de plataforma Ansible

## Estado
Propuesto

## Contexto
<stack actual: EKS + Argo CD, VMs long-lived, bare metal con switches Cisco,
secrets en Secrets Manager; dolor concreto: 70 playbooks sin owners, 2 playbooks
que despliegan a EKS "cuando Argo CD no responde", RFC pidiendo Ansible para una
app NestJS en K8s>

## Decisión

### 1. Dominios donde Ansible es la herramienta por defecto
- Day-2 ops sobre VMs long-lived (patching, cert rotation, sysctl)
- Bootstrap de nodos (kubeadm, control planes self-managed)
- Equipos de red (collections cisco.ios, arista.eos)
- Bare metal (collections dellemc.*, community.vmware)
- Incident response (playbooks como runbook ejecutable)
- Hardening CIS/STIG (ansible-lockdown)

### 2. Dominios donde Ansible NO se usa
- Apps en Kubernetes → Helm + Argo CD / Flux
- Aprovisionamiento cloud → Terraform / OpenTofu
- Configuración interna de contenedores → Dockerfile / Packer
- Reconciliación continua → operador K8s

### 3. Herramientas alternativas por dominio
```text
caso                                 | herramienta elegida   | rechazada
app a EKS                            | Helm + Argo CD        | Ansible
VPC + RDS + IAM                      | Terraform             | Ansible
AMI base con nginx + agent           | Packer + Ansible      | Ansible solo
cert rotation en 50 bastiones live   | Ansible               | nueva AMI
```

### 4. Immutable-first y rol de Packer
<AMI horneada con Packer usando Ansible como provisioner; TF usa la AMI;
drift = cero; Ansible en runtime solo para Day-2 ocasional>

### 5. Ownership, review y CI
<CODEOWNERS por path; review obligatorio; ansible-lint + molecule test en PR;
matrix Ubuntu 24.04 / Rocky 9>

### 6. Control plane operacional
<AWX como control plane; workflow templates con approval; EDA/rulebook para
auto-remediation acotada vía webhook de Alertmanager>

### 7. Excepciones y proceso
<RFC + ADR específico; aprobacion de platform-sre; sunset date obligatorio>

## Consecuencias
### Positivas
- ...
### Negativas
- ...

## Alternativas descartadas
### Alt A: "libertad total, cada equipo elige"
- Por qué no: ...
### Alt B: "prohibir Ansible y migrar todo a Terraform + operators"
- Por qué no: ...
```
