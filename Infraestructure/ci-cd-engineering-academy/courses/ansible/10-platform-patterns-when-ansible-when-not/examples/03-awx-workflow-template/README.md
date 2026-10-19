# Ejemplo 03 — AWX workflow template con approval y RBAC

> Lectura y análisis. Sin ejecución (no se levanta un AWX). Objetivo: ver cómo se compone un workflow operacional serio con approval node, RBAC y notificación.

## 1. Contexto

Escenario: la plataforma quiere exponer un workflow "**rotate-db-credentials**" que:

1. Lee el nuevo password desde AWS Secrets Manager.
2. Lo aplica en el RDS vía `community.aws.rds_instance`.
3. Espera **approval humano** antes de actualizar los consumers.
4. Hace rolling restart de los app servers que consumen la credencial.
5. Notifica el resultado a Slack.

En AWX esto se modela con un **workflow template** compuesto por varios **job templates** y un **approval node**.

## 2. Workflow (representación YAML conceptual)

AWX permite exportar/importar workflows via `awx-cli` o `awx.awx.workflow_job_template` collection. La forma lógica:

```yaml
# awx/workflows/rotate-db-credentials.yml
name: rotate-db-credentials
description: Rotacion controlada de credenciales de RDS con approval humano.
organization: platform
inventory: aws_ec2_prod
survey_enabled: true
survey:
  - question_name: "RDS instance id"
    variable: rds_instance_id
    type: text
    required: true
  - question_name: "Dry run?"
    variable: dry_run
    type: multiplechoice
    choices: ["yes", "no"]
    default: "yes"

workflow_nodes:

  - identifier: step-1-fetch-secret
    unified_job_template: jt-fetch-new-secret
    success_nodes:
      - step-2-apply-to-rds

  - identifier: step-2-apply-to-rds
    unified_job_template: jt-apply-rds-password
    success_nodes:
      - step-3-approval

  - identifier: step-3-approval
    approval_node:
      name: "Approve consumer rollout"
      description: |
        El password ya se roto en RDS. Aprobar para continuar con el rolling
        restart de los app servers. Rechazar aborta y deja los consumers con
        el password viejo (fallaran autenticacion hasta rollback manual).
      timeout: 1800   # 30 min; expira = rechazado
    success_nodes:
      - step-4-rolling-restart
    failure_nodes:
      - step-99-notify-aborted

  - identifier: step-4-rolling-restart
    unified_job_template: jt-rolling-restart-app
    success_nodes:
      - step-5-notify-success
    failure_nodes:
      - step-99-notify-aborted

  - identifier: step-5-notify-success
    unified_job_template: jt-notify-slack-success

  - identifier: step-99-notify-aborted
    unified_job_template: jt-notify-slack-aborted
```

## 3. Piezas de AWX usadas

- **Workflow template**: contenedor del grafo.
- **Job templates** (los `jt-*`): cada uno apunta a un playbook con su inventory, credentials y extra vars.
- **Approval node**: nodo humano. Timeout obligatorio (si expira, se trata como fallo).
- **Survey**: formulario que valida inputs del operador antes de arrancar.
- **Notification templates**: Slack, email, PagerDuty — asociados al workflow para éxito/fallo.
- **RBAC**: equipos con rol `Execute` sobre este workflow son los únicos que pueden lanzarlo; `Approve` separado para el approval node.

## 4. RBAC típico

| Rol AWX | Alcance | Equipos |
|---------|---------|---------|
| `Admin` del workflow | Edita el workflow, los job templates, y los credentials. | platform-sre |
| `Execute` | Lanza el workflow (abre el survey, dispara el run). | dba, platform-sre |
| `Approve` sobre el approval node | Puede aprobar/rechazar el paso 3. | dba-leads, platform-oncall |
| `Read` | Ve runs y logs, no lanza. | security, auditores |

Observa que **"ejecutar" y "aprobar" son roles separados**: el DBA que lanza la rotación no es el que aprueba el rollout a consumers. Esto es segregation of duties para cambios en prod.

## 5. Qué garantiza este workflow

- **Trazabilidad**: cada run tiene ID, usuario, inputs del survey, logs de cada job template, fecha/hora de approval, aprobador.
- **Interrumpibilidad**: si el approval se rechaza, los pasos 4–5 no corren y se dispara la notificación de abort.
- **Reproducibilidad**: el workflow vive como código (exportado con `awx-cli export` al repo), revisado en PR, aplicado con `awx-cli import` desde CI.
- **Observabilidad**: notificación Slack con link al run; logs al SIEM via Fluent Bit sidecar del awx-task pod.

## 6. Dónde encaja Event-Driven Ansible

El workflow anterior es **operador-iniciado**. Para flujos reactivos (p. ej. "si un host reporta `disk > 90%` tres veces en 5 min, correr playbook de limpieza"), se usa `ansible-rulebook`:

```yaml
# rulebook snippet
- name: Disk full auto-cleanup
  hosts: all
  sources:
    - ansible.eda.alertmanager:
        host: 0.0.0.0
        port: 5000
  rules:
    - name: Trigger cleanup on disk alert
      condition: event.alert.labels.alertname == "DiskFull"
      action:
        run_job_template:
          name: jt-disk-cleanup
          organization: platform
```

El rulebook consume webhooks de Alertmanager y dispara el job template cuando la condición se cumple. Útil para auto-remediation acotada; **no** reemplaza a operadores K8s para reconciliación continua de recursos.

## 7. Qué llevarse

> AWX/AAP convierte Ansible en una plataforma operacional con RBAC, approval y auditoría. Sin esta capa, Ansible en producción sigue siendo "scripts bash con YAML". Con esta capa, es un control plane de operaciones comparable a una herramienta ITSM, pero más barato y más expresivo.
