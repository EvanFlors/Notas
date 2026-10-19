# ADR 001 — Mutable (TF+Ansible) vs immutable (Packer+Ansible)

> Referencia de solución. Tu ADR puede llegar a conclusiones distintas si las defiendes bien — lo importante es el **razonamiento documentado**, no copiar esta decisión.

## Estado

Aceptado — 2026-10-19. Revisar en 6 meses o cuando aparezca un nuevo workload que no encaje claramente.

## Contexto

La plataforma hospeda hoy tres workloads de perfiles muy distintos:

- **`legacy-billing`**: monolito Java en 4 VMs on-prem (VMware). Última release hace 11 meses. Config cambia por tickets manuales. Pico predecible día 1 y 15. Equipo dueño: Finanzas IT (no plataforma). Reconstruir una VM requiere coordinación de 2 personas y una ventana planificada.
- **`checkout-api`**: API HTTP nueva en EC2 detrás de ALB, autoscaling 2–10 instancias. Deploy 3–5 veces/semana. SLA 99.9%. Secretos en AWS Secrets Manager; estado en RDS + DynamoDB. Equipo backend de 4 personas iterando rápido.
- **`analytics-platform`**: batch en EKS. Pods + CronJobs + Argo Workflows. Imágenes Docker gestionadas por el equipo de datos. No hay VMs mutables.

El debate ha sido "¿todo immutable o seguimos con mutable para algunos?". Este ADR cierra ese debate.

**Constraints** aplicables:

- No podemos forzar al equipo de `legacy-billing` a reescribir su pipeline en 2026.
- `checkout-api` tiene presupuesto para madurar su stack de deploy.
- Equipo de plataforma de 3 personas — no podemos mantener 5 pipelines distintos.

## Decisión

### 1. Patrón por workload

- **`legacy-billing` → MUTABLE (TF + Ansible converge).** Las VMs on-prem no se recrean trivialmente; no hay autoscaling; el valor de pasar a immutable no compensa el coste de rehacer el pipeline con un equipo que no es nuestro. TF describe la topología VMware (vSphere provider), Ansible converge config vía inventario estático + SSH.
- **`checkout-api` → IMMUTABLE (Packer + Ansible → AMI → TF).** Hornear la AMI elimina drift, acelera arranque de instancias (autoscaling-friendly), permite rollback por `ami_id` anterior. Los secretos ya viven en Secrets Manager, el estado en RDS/DynamoDB — nada bloquea migrar.
- **`analytics-platform` → NO-ANSIBLE.** Workload K8s nativa; usar Ansible aquí sería imponer una capa sin valor. La config vive en manifiestos / Helm charts aplicados por Argo CD (GitOps). Ansible **no** entra. Si en algún momento necesitamos bootstrap de nodos EKS *fuera* del managed node group, revisamos este punto.

### 2. Tabla de trade-offs

| Dimensión          | Mutable (TF+Ansible)                                       | Immutable (Packer+AMI)                                           |
|--------------------|------------------------------------------------------------|------------------------------------------------------------------|
| **Drift**          | Alto — un `ssh` manual revierte solo cuando corres Ansible | Bajo — nadie `ssh`-ea porque la instancia va a morir             |
| **Blast radius**   | Un cambio afecta todos los hosts del grupo al vez           | Cambio = nueva AMI; rollouts canary/rolling naturales            |
| **Rollback**       | Revertir playbook + re-correr (lento, humano en el loop)   | `terraform apply -var ami_id=<anterior>` (segundos)              |
| **Build time**     | Minutos (ansible-playbook sobre host existente)            | Minutos adicionales (packer build) + segundos de arranque EC2    |
| **Secretos**       | Fácil de leer en runtime (lookup / community.aws)          | Igual — se inyectan en user-data al arrancar                     |
| **Estado en disco**| OK si el host es long-lived                                | Prohibido — disco local es efímero                               |
| **Velocidad iter.**| Rápida (editar playbook, correr)                           | Media (editar playbook, build AMI, apply TF)                     |
| **Autoscaling**    | Hostil — nueva instancia no está lista hasta correr Ansible | Nativo — nueva instancia ya está lista desde boot                |

### 3. AWX / AAP

- **`legacy-billing`**: AWX **sí aporta** valor. El equipo de Finanzas IT quiere surveys para lanzar jobs rutinarios (patching, re-deploy de config) sin tocar YAML, y necesitamos audit log para compliance. Un AWX compartido con RBAC lo da.
- **`checkout-api`**: AWX **no** aporta. El flujo es `git push` → CI → `packer build` → `terraform apply`. No hay operadores humanos corriendo playbooks ad-hoc.
- **`analytics-platform`**: AWX **no** aplica. Argo CD + Argo Workflows cubren orquestación.

Decisión: desplegamos **AWX OSS** sobre nuestro cluster K8s compartido, lo usamos para `legacy-billing` y para scripts administrativos puntuales. Si el consumo crece y necesitamos soporte formal, evaluamos AAP (Red Hat) en 12 meses.

### 4. Boundaries (resumen)

- **Terraform** es la fuente de verdad de topología cloud (VPC, EC2, RDS, S3, IAM, ALB).
- **Packer** construye AMIs para `checkout-api`.
- **Ansible** configura `legacy-billing` (patrón mutable) y es el provisioner dentro de Packer para `checkout-api`.
- **Helm + Argo CD** gestionan `analytics-platform`. Ansible **no** entra.
- **Secretos** siempre en AWS Secrets Manager (consultados en runtime), nunca horneados.

## Consecuencias

### Positivas

- Tres patrones alineados con tres realidades distintas (no forzamos uno solo).
- Rollback trivial en `checkout-api` (basta cambiar `ami_id`).
- Drift controlado en `checkout-api` (inmutable por diseño).
- Equipo de `legacy-billing` sigue operando como lo hacía, con la mejora de AWX para audit y surveys.
- No añadimos capas innecesarias a `analytics-platform`.

### Negativas

- Mantenemos **dos** pipelines distintos: mutable (ans-converge) e inmutable (packer-build-then-tf). Mayor carga cognitiva para el equipo de plataforma.
- **AMI sprawl** en `checkout-api`: cada deploy produce una AMI. Necesitamos un policy de lifecycle para limpiar AMIs > 30 días no referenciadas (Terraform data source busca la más reciente, pero las viejas se acumulan y pagan por EBS snapshot).
- Operar AWX requiere mantener su cluster K8s y actualizarlo (operador oficial lo facilita, pero no es cero coste).
- Si `legacy-billing` crece o necesita autoscaling, su patrón mutable se vuelve insostenible — toca revisar el ADR.

## Alternativas descartadas

### Alt A — Todo immutable (migrar `legacy-billing` también a Packer)

Rechazada por:

1. Coste de rehacer el pipeline de un equipo que no es nuestro (`legacy-billing` lo mantiene Finanzas IT).
2. On-prem VMware no tiene autoscaling — el valor principal del inmutable (recrear rápido) no se materializa.
3. Riesgo alto: el monolito tiene config implícita acumulada en los hosts durante años; recrear desde cero destapa bugs que llevan latentes meses.

### Alt B — Todo mutable (quedarnos en TF + Ansible converge para `checkout-api`)

Rechazada por:

1. Drift latente — ya hemos visto 3 incidentes en 2026 donde un host de `checkout-api` tenía un `/etc/nginx/conf.d/foo.conf` que nadie recordaba haber puesto.
2. Autoscaling con `checkout-api` falla: una nueva instancia tarda 90-120s en estar lista (apt install + ansible-playbook); el pico la deja atrás.
3. Rollback complejo: hoy requiere revertir el PR del playbook, mergear, re-correr pipeline. Con inmutable, un `terraform apply -var ami_id=anterior` tarda segundos.

### Alt C — Meter `analytics-platform` dentro del alcance de Ansible

Rechazada por:

1. Argo CD y Argo Workflows ya resuelven el problema con mejor UX para el equipo de datos.
2. Ansible sobre K8s es un smell — complica el modelo mental y añade una capa sin valor.
3. No tenemos capacidad ni interés en soportar un flujo `ansible → k8s` cuando GitOps es el estándar.
