# ans-10 — Lección: patrones de plataforma, cuándo Ansible y cuándo no

> 11 secciones. Síntesis de capstone. Prerrequisitos: `ans-05`, `ans-06`, `ans-08`, `ans-09`.

---

## 1. La tesis del módulo

Después de nueve módulos, el riesgo es haber internalizado un reflejo: "problema de infraestructura → `ansible-playbook`". Este módulo rompe ese reflejo. Ansible es una herramienta estrecha y profunda: brilla en **configuración de hosts long-lived**, **operaciones Day-2**, y **flujos imperativos reproducibles** sobre fleet heterogénea. Fuera de ese dominio, hay herramientas mejores.

La tesis es doble:

1. **Donde Ansible encaja, encaja mejor que casi nada.** Agentless, idempotente, con una comunidad enorme de módulos, trivial de leer para alguien que lea YAML. En Day-2 ops sobre bare metal o VMs long-lived, nada lo supera en relación esfuerzo/alcance.
2. **Donde no encaja, usarlo es activamente dañino.** Un playbook que "despliega una app a Kubernetes" compite con Helm/Kustomize/Argo CD en terreno donde esas herramientas son nativas, drift-free y declarativas; el playbook perderá cada reconciliación.

El trabajo del arquitecto de plataforma no es "evangelizar Ansible". Es **publicar un contrato** que diga, en una página, qué pertenece a Ansible y qué no, para que los equipos consumidores decidan rápido y los reviewers tengan algo citable en el PR.

---

## 2. Dónde Ansible aporta valor (los dominios "sí")

### 2.1 Day-2 operations sobre hosts long-lived

Rotar certificados, aplicar parches críticos fuera de ciclo, auditar `sshd_config` en 300 hosts, cambiar `MaxSessions` en todos los bastiones. Son tareas **imperativas**, **ocasionales**, sobre **hosts que ya existen** y que no se van a reemplazar. Reconstruir la imagen y reiniciar 300 hosts cuesta más que un playbook de 20 líneas con `serial: "20%"` y `--check` antes.

### 2.2 Bootstrap de nodos (incluido Kubernetes self-managed)

Un cluster EKS gestionado no necesita Ansible; sus nodos vienen horneados. Pero un cluster `kubeadm` self-managed sobre bare metal **sí**: hay que instalar containerd, kubelet, generar el join token, configurar el `cgroup driver`, aplicar sysctls, montar etcd en disco encriptado. Esto es terreno Ansible histórico y lo sigue siendo.

### 2.3 Equipos de red (Arista, Cisco, Juniper, F5)

Las collections `cisco.ios`, `arista.eos`, `junipernetworks.junos`, `f5networks.f5_modules` son maduras. Day-2 sobre switches de datacenter — aplicar una ACL, cambiar una VLAN en 400 puertos, rotar credenciales RADIUS — es Ansible-tierra pura. **Terraform también tiene providers de red** (Juniper, Cisco), pero su modelo declarativo encaja mal con flujos imperativos tipo "ejecuta este comando en este orden en este dispositivo".

### 2.4 Bare metal y "hardware raro"

Servidores físicos en rack, appliances (storage, NAS), hipervisores on-premise (VMware vSphere, Proxmox, oVirt), sistemas industriales. Donde no hay API cloud, Ansible con SSH/WinRM/REST sigue siendo lo que funciona. Collections como `community.vmware`, `dellemc.openmanage`, `community.windows` cubren mucho de este espacio.

### 2.5 Incident response y "runbook ejecutable"

Un runbook escrito en prosa es un documento muerto el día del incidente. Un runbook escrito como playbook (con `--check` y `--diff` para preview, con `tags` para pasos selectivos) es ejecutable, auditable y evoluciona con el repo. Patrón: el SRE abre `playbooks/incident/<id>.yml`, lee las comentarios, ejecuta por tag en orden. Mejor aún con **Event-Driven Ansible** reaccionando a alertas de Alertmanager/PagerDuty.

### 2.6 Compliance y hardening (CIS, STIG, PCI)

Las collections `ansible-lockdown` (CIS Ubuntu, CIS RHEL, STIG) son referencias. Aplican, verifican y reportan diffs sobre un baseline conocido. Alternativa Chef InSpec existe pero es más fragmentada; en 2026 la mayoría de equipos de compliance que aún operan sobre VMs usan Ansible + ansible-lockdown.

### 2.7 Cuando "lo que mide valor" es velocidad de reparación en producción

Si tu MTTR mejora porque un operador puede abrir una PR con un playbook, revisarlo en 10 minutos y aplicarlo con AWX con un approval node, has ganado. Esto compite con "cambiar la AMI y rotar la ASG": a veces es más lento, a veces más rápido. Ansible gana cuando el cambio es puntual y reversible; pierde cuando se repite semana a semana (entonces hornear).

---

## 3. Dónde Ansible estorba (los dominios "no")

### 3.1 Aplicaciones que corren en Kubernetes

Un cluster K8s **reconcilia continuamente** el estado deseado. Un playbook corre una vez y se olvida. Ejecutar `kubectl apply` desde Ansible funciona, pero compite con herramientas diseñadas para K8s: **Helm** (templating y versioning), **Kustomize** (overlays por entorno), **Argo CD / Flux** (GitOps con drift detection y auto-sync). El reflex de "despliego mi app con un playbook porque conozco Ansible" produce drift, falta de rollback nativo y zero observabilidad de reconciliación. Síntoma típico: el playbook funciona la primera vez; el operador K8s revierte parte del cambio; nadie lo nota hasta la siguiente ejecución.

### 3.2 Aprovisionamiento cloud (crear VPCs, buckets, RDS, IAM)

**Terraform / OpenTofu / Pulumi / CloudFormation / CDK** son declarativos, con state, plan/apply, graph de dependencias, drift detection y proveedores de primera clase. Los módulos `amazon.aws.ec2_instance`, `community.aws.rds_instance`, `google.cloud.gcp_compute_instance` existen y funcionan, pero reconstruyen a mano lo que Terraform da gratis. Un playbook que crea una VPC es un Terraform mal implementado. Patrón correcto: **TF crea la infraestructura; Ansible configura los hosts que TF creó** (ver `ans-09`).

### 3.3 Configuración interna de contenedores

Un `Dockerfile` que termina con `RUN ansible-playbook configure.yml` es una señal de que la imagen no está horneada. La configuración de un contenedor pertenece al **build time** (en el `Dockerfile` o en un Packer HCL con builder `docker`), no al **run time**. Excepción pequeña: cuando necesitas aplicar un overlay en el *entrypoint* porque el contenedor recibe parámetros externos — pero eso es un script shell, no Ansible.

### 3.4 Reconciliación continua / self-healing

Ansible es **push bajo demanda**. Si quieres que el sistema se repare solo cuando alguien cambia una config, necesitas un controlador que observe y actúe: **operadores de Kubernetes** (Operator SDK, Kubebuilder), **Nomad**, **systemd + ConditionPath** para casos pequeños. "Cron de `ansible-playbook` cada 15 minutos" es una pseudo-reconciliación: lenta, sin backoff, sin leader election, y rompe cuando el host está apagado.

### 3.5 Service mesh, routing dinámico, feature flags

Estos cambian minuto a minuto, por API, con observabilidad propia. **Istio/Linkerd**, **Consul**, **LaunchDarkly/Unleash** son los sistemas correctos. Un playbook que rota flags por SSH es un chiste doloroso.

### 3.6 Secret rotation operacional

Rotar un secret debe ser **evento → nueva versión → consumidores recargan**. Ansible puede *consultar* un secret manager (vía lookup) y entregarlo a un host en un render; **no debe ser el motor de rotación**. Para rotación usa AWS Secrets Manager scheduled rotation, Vault dynamic secrets, cert-manager en K8s. Ver `ans-06`.

### 3.7 Builds de software

Compilar un binario en el host con Ansible es un anti-patrón: no es reproducible, depende del estado del host, no cachea. Usa el CI (GHA, GitLab CI, Buildkite) para builds, publica artefactos a un registry, y en Ansible solo descarga el artefacto ya construido.

---

## 4. La matriz "sí / no" en una página

| Caso de uso | Ansible | Terraform | Helm/Argo | Packer | Operador K8s |
|-------------|---------|-----------|-----------|--------|--------------|
| Crear VPC, subnets, buckets | ❌ | ✅ | — | — | — |
| Hornear una AMI con todo instalado | 🔄 (como provisioner de Packer) | — | — | ✅ | — |
| Configurar sshd y users en 300 VMs long-lived | ✅ | ❌ | — | 🔄 (si se rotan AMIs) | — |
| Desplegar app a EKS | ❌ | ❌ | ✅ | — | — |
| Operador que reconcilia un CRD propio | ❌ | ❌ | — | — | ✅ |
| Cambiar VLAN en 400 switches Cisco | ✅ | 🔄 (posible, menos natural) | — | — | — |
| Bootstrap de un cluster kubeadm bare metal | ✅ | 🔄 (parcial) | — | 🔄 | — |
| Rotar un certificado TLS en 50 bastiones | ✅ | ❌ | — | 🔄 | — |
| Rotar un secret aplicativo en runtime | ❌ | ❌ | 🔄 (ExternalSecrets) | — | ✅ (External Secrets Operator) |
| Hardening CIS en fleet mixta Ubuntu/RHEL | ✅ | ❌ | — | ✅ (si todo pasa por AMI) | — |
| Service mesh config dinámica | ❌ | ❌ | 🔄 | — | ✅ |

Leyenda: ✅ encaja; ❌ no encaja; 🔄 posible pero no la mejor opción; — fuera de alcance.

Esta tabla es la base del contrato que vas a escribir en la actividad 01. Imprímela mental.

---

## 5. Inventory dinámico a escala

En una org con 10 hosts, el inventory estático en `hosts.yml` funciona. En una org con 10 000 hosts repartidos entre AWS, GCP y bare metal, no.

### 5.1 Plugins de inventario cloud

- **`amazon.aws.aws_ec2`**: lista instancias EC2 por filtros (`tag:Role=app`, `instance-state-name=running`). Agrupa por tag con `keyed_groups`.
- **`google.cloud.gcp_compute`**: equivalente en GCP, filtros por label y por zona.
- **`azure.azcollection.azure_rm`**: equivalente en Azure, filtros por resource group y tags.
- **`kubernetes.core.k8s`**: inventario de pods, usado raras veces (K8s se gestiona con sus propias herramientas, ver §3.1).

Ejemplo `aws_ec2.yml`:

```yaml
plugin: amazon.aws.aws_ec2
regions:
  - eu-west-1
  - eu-central-1
filters:
  tag:Environment: prod
  instance-state-name: running
keyed_groups:
  - key: tags.Role
    prefix: role
  - key: placement.availability_zone
    prefix: az
hostnames:
  - tag:Name
  - private-ip-address
compose:
  ansible_host: private_ip_address
cache: true
cache_plugin: jsonfile
cache_timeout: 300
cache_connection: /var/tmp/ansible-ec2-cache
```

### 5.2 Dolor típico a escala

- **Queries lentas**: `DescribeInstances` con filtros amplios en una cuenta con 20 000 EC2 tarda **minutos**. Mitigación: filtros estrictos, split por región, cache (`cache_timeout`), evitar `--list` en cada run.
- **Rate limits de la API cloud**: `ThrottlingException` cuando hay muchos CI runners pidiendo inventario a la vez. Mitigación: cache compartido en S3 (`cache_plugin: ansible.builtin.jsonfile` montado o cache plugin externo), o un **CMDB intermedio** (Netbox, NetBox + plugin `netbox.netbox.nb_inventory`).
- **Hosts "fantasma"**: instancias que arrancan y mueren entre `--list` y la ejecución. Un `serial: 10%` puede intentar conectar con un host que ya no existe. Mitigación: `wait_for_connection` + `ignore_unreachable: true` en el play.
- **Multi-cloud**: usar `constructed` inventory para unificar grupos a partir de múltiples plugins (`aws_ec2`, `gcp_compute`, estático) con reglas de composición consistentes.

### 5.3 Límite práctico

Más allá de ~10 000 hosts por run, Ansible pierde brillo. Alternativas: **split por región o por team**, pasar al modelo pull con **Puppet** o **Chef** si realmente es ese el tamaño, o migrar a immutable images (Packer) para que la configuración viva en el build pipeline y Ansible no toque ese fleet.

---

## 6. Immutable-first como mindset

El patrón recomendado en 2026 para workloads cloud es:

1. **Packer** construye una AMI/golden image **ejecutando Ansible como provisioner** durante el build.
2. **Terraform** usa esa AMI en una ASG o en un launch template.
3. Cuando cambia la config: nueva AMI → nueva ASG rolling → viejos nodos mueren.
4. **Ansible nunca toca los hosts en producción.**

Ventajas: cero drift, rollback trivial (volver a la AMI anterior), auditoría = diff entre AMIs. Costo: tiempo de build (minutos), disciplina de versionado de AMIs.

Patrón mutable (Ansible configura hosts long-lived) sigue siendo correcto para: bare metal, hardware raro, legacy que no se puede reconstruir, y Day-2 fuera del happy path. Pero deja de ser la **opción por defecto**.

**Regla operativa**: si el workload corre en una ASG o en pods, inmutable. Si corre en un servidor físico o un VMware que vive 2 años, mutable con disciplina.

---

## 7. Ownership de playbooks como código

Un playbook en el repo es código. Las mismas reglas que aplicas a un microservicio aplican aquí:

- **CODEOWNERS por path**: `playbooks/network/* @network-team`, `roles/postgres/* @data-platform`. GitHub bloquea el merge sin aprobación del owner.
- **Versionado SemVer de roles**: `v1.3.2`, cambios breaking suben MAJOR. `requirements.yml` del consumidor fija la versión.
- **Review obligatorio en PR**: no se mergea playbook sin otro par de ojos. Incluso para hotfixes — se mergea con `--check` + `--diff` capturado en el PR.
- **Lint + Molecule en CI**: `ansible-lint` + `molecule test` en cada PR. Matrix de distros (Ubuntu 22.04/24.04, Debian 12, Rocky 9).
- **README por role**: contrato explícito: vars esperadas, OS soportados, side effects, ejemplo mínimo. Un role sin README es un role sin contrato.
- **Changelog**: `CHANGELOG.md` por role/collection con cada bump de versión. Si usas `antsibull-changelog`, se genera desde fragments.

Anti-patrón habitual: un repo `ansible/` compartido entre todos los equipos, sin owners, con 400 playbooks que nadie sabe quién mantiene. Es un cementerio de código.

---

## 8. Seguridad operativa: SSH y secretos

Dos frentes.

### 8.1 Acceso a hosts

- **No** llaves SSH largas de operador en el runner. Un runner comprometido = acceso a todo el fleet.
- **Workload identity** para el CI/AWX: OIDC desde GHA, SPIFFE/SPIRE en infra interna, cert-based SSH con **Teleport**/**Boundary** emitiendo certificados cortos (minutos).
- **Operadores humanos**: Yubikey u otro HSM, nunca password-only. SSH agent forwarding — ponderadamente, con `restrict` flag y auditoría.
- **Bastion efímero**: la sesión del operador abre un bastion que vive el tiempo de la ventana de cambio y muere; Ansible pasa por él. Reduce ventana de ataque.

### 8.2 Secretos usados por los playbooks

- `ansible-vault` sigue siendo útil para **secrets de bootstrap** (p. ej. token inicial para que el host se registre contra Vault). Para el resto, **lookup** contra el secret manager en tiempo de ejecución (`community.hashi_vault.vault_kv2_get`, `amazon.aws.aws_secret`, `azure.azcollection.azure_keyvault_secret`).
- `no_log: true` en tasks que manipulan secretos — siempre. Un `register:` + `debug:` filtra el password al log del runner y de ahí al SIEM.
- **Rotación**: no la hace Ansible, la hace el secret manager (scheduled rotation en Secrets Manager, dynamic secrets en Vault). Ansible solo *consume* la versión actual.

Ver `ans-06` para profundidad.

---

## 9. Auditoría e integración con el ecosistema de operaciones

En producción, "corrí un playbook" no basta. Necesitas:

- **AWX / AAP** como control plane: inventarios centralizados, RBAC, job templates, workflow templates, surveys para inputs validados, approval nodes para cambios sensibles.
- **Logs al SIEM**: AWX emite eventos a syslog/Fluent Bit; se envían a Splunk/ELK/Loki/Datadog para correlación.
- **Notificaciones**: integración con PagerDuty/Opsgenie/Slack. Un job que falla en prod a las 03:00 debe despertar a alguien, no quedarse en el UI.
- **Change management**: integración con ServiceNow/Jira si la org lo exige. El workflow template abre el change, espera aprobación, ejecuta, cierra el change con el output.
- **Event-Driven Ansible**: `ansible-rulebook` con fuentes (Kafka, webhook, Alertmanager, CloudEvents) dispara playbooks en respuesta a eventos. Patrón para auto-remediation acotada (reiniciar un servicio tras N alertas idénticas).

Sin esto, Ansible es "scripts bash con YAML". Con esto, es una plataforma operacional.

---

## 10. Deprecation path: cuándo retirar un playbook

Un playbook que ya no pertenece al dominio Ansible (porque la app migró a K8s, porque el fleet se hizo inmutable, porque hay un servicio managed que lo cubre) debe **retirarse**, no dejarse "por si acaso". Un playbook muerto es deuda que un junior correrá por error en seis meses.

### 10.1 Criterios para marcar un playbook como deprecado

1. **Dominio cambió**: la app ahora corre en EKS/Fargate/Cloud Run y hay Helm/Argo CD cubriendo el deploy.
2. **Herramienta nueva encaja mejor**: existe un operador K8s, un servicio managed, un módulo TF que lo hace mejor.
3. **Riesgo elevado y uso bajo**: el playbook se corre 2 veces al año y manipula producción; mantenerlo cuesta más que lo que aporta.
4. **Dependencia abandonada**: usa una collection sin mantenedores desde hace 18 meses, o un módulo custom cuyo autor dejó la empresa.
5. **Fleet migrado**: los hosts a los que apunta ya no existen o están programados para rotación.

### 10.2 Fases estándar de un plan de deprecación

1. **Anuncio** (semana 0): PR al repo marcando el playbook con un header `# DEPRECATED — scheduled removal: <date>`, mensaje en Slack a los equipos consumidores, entrada en el changelog.
2. **Alternativa documentada** (semana 0–2): link al reemplazo (Helm chart, módulo TF, operador, runbook) con un ejemplo migrado.
3. **Freeze de features** (semana 2+): no se aceptan PRs de mejora; solo bugfixes críticos.
4. **Canary de corte** (semana N-2): deshabilitar el job template en AWX para un consumidor piloto; verificar que no hay escalado.
5. **Corte** (semana N): mover el playbook a un directorio `archived/`, eliminar el job template, cerrar el ticket.
6. **Post-mortem corto** (semana N+1): qué aprendimos, qué quedó pendiente, actualizar el contrato si procede.

### 10.3 Qué NO hacer

- "Lo dejamos por si acaso" — no. Se archiva.
- "Lo migramos cuando tengamos tiempo" — no. Se agenda.
- Borrar sin anunciar — no. Se comunica con margen (≥ 30 días para prod).

---

## 11. Lo que llevarse

Cinco ideas que resumen el módulo:

1. **Ansible es estrecho y profundo.** Donde encaja, encaja mejor que casi nada; fuera, hay mejores opciones.
2. **Immutable-first es la vía por defecto en cloud en 2026**; Ansible queda como provisioner de Packer y como Day-2 sobre long-lived.
3. **El contrato de plataforma vale más que cualquier playbook**. Una página citable en PR evita 50 discusiones.
4. **Deprecación es una práctica, no un accidente.** Un playbook que ya no pertenece a Ansible se retira con fecha, canary y comunicación.
5. **AWX/AAP + Event-Driven Ansible** convierten Ansible en plataforma operacional; sin ellos, sigue siendo YAML con SSH.

### Qué sigue

Fin del curso Ansible. El contrato que escribas en la actividad 01 entra en el capstone del programa, junto a los contratos de Terraform, Docker/K8s y DevSecOps.
