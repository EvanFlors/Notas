# Ejemplo 01 — Matriz de boundaries de Ansible

> Lectura y análisis. Sin ejecución. Objetivo: fijar en memoria la clasificación "sí / no / depende" para los casos de uso más frecuentes.

## 1. La matriz canónica

Esta es la tabla base del contrato de plataforma de la actividad 01. Las columnas son herramientas alternativas; las celdas indican la elección recomendada.

| # | Caso de uso | Ansible | Terraform / OpenTofu | Helm / Argo CD | Packer | Operador K8s | Nota |
|---|-------------|:-------:|:--------------------:|:--------------:|:------:|:------------:|------|
| 1 | Crear VPC, subnets, buckets S3, RDS | no | sí | — | — | — | Declarativo, state, drift detection. |
| 2 | Crear VPC en bare metal (Netbox + switches) | sí | parcial | — | — | — | Terraform tiene providers de red; en Day-2 switches reales Ansible gana. |
| 3 | Instalar nginx + certs en 300 VMs long-lived | sí | no | — | depende | — | Si las VMs se rotan por AMI, Packer; si no, Ansible. |
| 4 | Hornear AMI con todo instalado | provisioner | — | — | sí | — | Packer orquesta, Ansible actúa como provisioner. |
| 5 | Desplegar app a EKS | no | no | sí | — | — | Helm chart + Argo CD / Flux. |
| 6 | Reconciliar un CRD propio | no | no | — | — | sí | Operator SDK, Kubebuilder. |
| 7 | Cambiar VLAN en 400 switches Cisco | sí | parcial | — | — | — | `cisco.ios` collection es madura. |
| 8 | Bootstrap kubeadm bare metal | sí | parcial | — | parcial | — | Instalar containerd, kubelet, join. |
| 9 | Rotar cert TLS en 50 bastiones | sí | no | — | depende | — | Si bastiones son inmutables, nueva AMI; si no, playbook. |
| 10 | Rotar secret aplicativo en runtime | no | no | ExternalSecrets | — | ExternalSecretsOperator | AWS Secrets Manager + ESO. |
| 11 | Hardening CIS en fleet mixta Ubuntu/RHEL | sí | no | — | sí | — | `ansible-lockdown.*_cis` collections. |
| 12 | Service mesh config dinámica | no | no | parcial | — | sí | Istio/Linkerd operators. |
| 13 | Compilar binario de la app | no | no | — | parcial | — | CI (GHA/GitLab), no Ansible. |
| 14 | Configuración interna de contenedor | no | no | — | sí | — | Hornear en build time, no en run. |
| 15 | Day-2 ad-hoc "cambiar un sysctl en todos los nodos" | sí | no | — | parcial | — | Mejor nueva AMI si es recurrente. |
| 16 | Runbook de incident response | sí | no | — | — | — | Playbook con tags por paso. |
| 17 | Event-driven auto-remediation (reiniciar servicio tras N alertas) | sí (EDA) | no | — | — | parcial | `ansible-rulebook` + webhook. |

Leyenda:

- **sí** = herramienta recomendada por defecto.
- **no** = anti-patrón o claramente inferior.
- **parcial** = posible pero no la primera elección.
- **depende** = depende del contexto; justificar.
- **provisioner** = Ansible usado como auxiliar dentro de otra herramienta.
- **—** = fuera de alcance de esa herramienta.

## 2. Lectura clave

1. **Las filas con "no" en Ansible y "sí" en otra columna son los límites duros del contrato.** Son las que vas a citar cuando un equipo diga "quiero desplegar mi app EKS con Ansible". La respuesta es la fila 5.
2. **Las filas con "parcial" son zona de debate.** No las uses como regla, úsalas como invitación a abrir un ADR específico para ese caso.
3. **Fila 4 es el patrón más importante en 2026**: Ansible como provisioner de Packer. Donde la mayoría de orgs modernas acaban. No reemplaza al Ansible operacional (filas 3, 7, 8, 11, 16), lo complementa.
4. **Las filas 10, 12 y 17 muestran dónde Kubernetes operators ganan**: reconciliación continua con eventos. Ansible EDA cubre un trozo (fila 17) pero no reemplaza al operador para CRDs propios.

## 3. Cómo convertir esto en contrato

En la actividad 01 vas a escribir el contrato Ansible de tu organización. Esta tabla es el 60% del contenido. Lo que **tú** añades:

- Qué filas aplican a **tu** stack (p. ej. si no tienes bare metal, filas 2, 7, 8, 11 quedan "no aplica").
- Qué **excepciones** permites y bajo qué condiciones (p. ej. "fila 5 permitida solo para pre-prod si el equipo documenta el reemplazo en 90 días").
- Quién es **owner** del dominio (p. ej. "fila 7 — network-platform-team").
- Qué **deprecaciones** están activas (lo que escribirás en la actividad 02).

## 4. Anti-patrones recurrentes

Tres playbooks que ves repetidamente en orgs y que esta matriz rechaza:

1. **"Deploy mi microservicio con un playbook que corre `kubectl apply`"**. Fila 5. Reemplaza por Helm + Argo CD.
2. **"Crear la VPC desde Ansible porque Terraform es complicado"**. Fila 1. Reemplaza por Terraform/OpenTofu.
3. **"Rotar el password de la base con un cron de `ansible-playbook`"**. Fila 10. Reemplaza por Secrets Manager scheduled rotation o Vault dynamic secrets.

## 5. Qué llevarse

> Una matriz de 15–20 filas, publicada en el repo de la plataforma, hace más por evitar malas decisiones que 500 líneas de "best practices". La actividad 01 te hace escribir la tuya.
