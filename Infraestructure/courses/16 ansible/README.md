# Curso: Ansible

Roadmap especializado #14. Herramienta de **Configuration Management** (CM) y automatización de operación. Framing explícito: **no reemplaza IaC** (Terraform aprovisiona recursos; Ansible configura lo que ya existe). Útil hoy en escenarios *híbridos* y en Day-2 operations, no como alternativa general a IaC moderno.

## 1. Introducción

### Qué es

**Ansible** es una herramienta de automatización por línea de comandos para:

- **Configurar sistemas**: aplicar paquetes, archivos, servicios, usuarios, firewall en servidores existentes.
- **Desplegar aplicaciones**: pushar binarios/configs/charts a un parque de hosts.
- **Orquestar operaciones Day-2**: rolling restarts, patching, rotación de credenciales, drenaje de nodos.

Características que la definen:

- **Agentless**: no requiere agente en los nodos — conecta por SSH (Linux/Unix) o WinRM (Windows); solo pide Python en el target.
- **Push**: Ansible decide cuándo y qué aplicar (opuesto al modelo pull de Chef/Puppet).
- **Declarativa-ish**: *módulos* idempotentes expresan estado deseado, pero el flujo general (tasks en playbooks) es imperativo-ordenado.
- **YAML + Jinja2**: playbooks son YAML templado con Jinja2.

### Historia (síntesis)

- **2012** — Michael DeHaan libera Ansible como alternativa simple a Chef/Puppet (sin agente, sin DSL propio).
- **2015** — Red Hat adquiere Ansible Inc.; versión *Tower* comercial (hoy **AAP / AWX**).
- **2019+** — Reorganización del core: separación en **ansible-core** + **collections** distribuidas vía **Ansible Galaxy**/Automation Hub.
- **2022+** — Automation Hub + Ansible Content Signing; **Event-Driven Ansible** (reactivo a eventos externos: Kafka, webhooks, CloudEvents).
- **2024+** — Mayor foco en **network automation**, **SaaS Ansible Lightspeed** (asistente AI, con reservas), AAP 2.x.

### Problemas que resuelve

- Configurar un parque heterogéneo de servidores de forma reproducible.
- Automatizar operaciones repetitivas que no son "aprovisionamiento de recursos" (es decir: cosas que Terraform no hace idóneamente).
- Patching, rotación, upgrades controlados, drenaje de nodos.
- Automatización en **appliances de red** (Cisco/Juniper/Arista) donde no hay otra opción.
- Automatización híbrida on-prem + cloud.

### Casos de uso

- **Day-2 ops** sobre VMs ya aprovisionadas (actualizaciones, parcheo, auditoría).
- **Bake de AMIs/golden images** combinado con **Packer** (Ansible como provisioner de Packer).
- **Hybrid stacks**: Terraform crea instancias, Ansible las configura. Más común en entornos legacy/híbridos que en "cloud-native puro".
- **Appliances de red** y entornos edge.
- Automatización ad-hoc operacional en incident response (p. ej. "reinicia nginx en estos 50 hosts").

### Arquitectura general

```
┌───────────────────────────────────────────────┐
│ Control node                                  │
│   - ansible / ansible-playbook (Python)       │
│   - inventory (static YAML/INI o dynamic)     │
│   - playbooks (YAML + Jinja2)                 │
│   - roles / collections                       │
│   - ansible-vault (secretos encriptados)      │
└───────────────────────────────────────────────┘
        │ SSH (Linux/Unix) o WinRM (Windows)
        │   envía un módulo Python/PowerShell al host,
        │   lo ejecuta, recibe JSON del resultado
        ▼
┌───────────────────────────────────────────────┐
│ Managed nodes                                 │
│   - solo requieren Python (y SSH)             │
│   - no hay agente                             │
└───────────────────────────────────────────────┘
```

Para operación a escala: **AWX** (OSS) o **Red Hat Ansible Automation Platform (AAP)** proveen UI, inventario centralizado, RBAC, scheduling, workflow visualization.

### Alternativas

- **Terraform / OpenTofu** — IaC (crear recursos). Complementaria, no sustituta.
- **Chef / Puppet / SaltStack** — otros CM, históricamente pull-based y con agente; en declive comparativo.
- **cloud-init** — bootstrap inicial de VMs.
- **Packer** — construir imágenes (AMIs, images QEMU) con un provisioner (Ansible, Shell, Chef…).
- **Nix / NixOS** — configuración declarativa funcional (nicho pero potente).
- **systemd + bash + distros con cloud-init** — para muchos casos simples la "no herramienta" basta.
- **Kubernetes operators** — para operación de software K8s-native, los operators superan ampliamente a Ansible.

### Ventajas / limitaciones

**Ventajas**: agentless, curva de entrada baja, enorme catálogo de módulos y collections, útil para legacy y mundos híbridos, ad-hoc operations muy ergonómico, soporta todos los OS/dispositivos relevantes.

**Limitaciones / riesgos**:
- **No es IaC**: operar recursos cloud con módulos `community.aws.*` funciona pero es feo comparado con Terraform; estado no se guarda.
- **Idempotencia depende del módulo**: `command`/`shell` *no son idempotentes* por default — es responsabilidad del autor.
- **YAML + Jinja2 se vuelve ilegible rápido** si se abusa de condicionales anidados.
- **Push-model** no escala tan bien a inventarios muy grandes (miles+) — hay optimizaciones (mitogen, forks, strategy free) pero empeora.
- **Testing históricamente débil** — Molecule mejora pero sigue siendo menos maduro que test de código.
- Modelo mental **"configuración mutable"** no encaja bien con la práctica moderna de **immutable infrastructure** (containerizar + rotar imágenes es más predecible).

### Relación con el programa

- **Alternativa / complemento** a Terraform (D7). Priorizado "cuando aporta" (hybrid/legacy/Day-2), no "por default".
- Puede ser **provisioner de Packer** para generar AMIs (patrón limpio: Packer bake, Ansible configure una vez, TF aplana la AMI resultante).
- Útil para **operación de clusters self-managed** (kubeadm, bare metal) y para **appliances de red**.
- Para apps en Kubernetes: **no** se usa Ansible — ahí viven Helm / Kustomize / GitOps.

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | T-2 Linux (SSH, permisos, systemd básico). T-3 Networking (SSH, firewall). Nociones básicas Python. |
| Recomendados | Curso **terraform** completo (para entender dónde empieza y termina CM vs IaC). Curso **docker** (para contrastar immutable vs mutable). |
| Complementarios | Curso **aws** o **gcp** (para dynamic inventory y módulos cloud). |

## 3. Organización (4 niveles)

El curso tiene **10 módulos**. Más corto por diseño: Ansible es herramienta táctica, no base del stack moderno.

- **Nivel 1 — Fundamentos** (3): CM vs IaC + setup + inventory + ad-hoc, playbooks (plays/tasks/modules/handlers), variables/facts/templates Jinja2.
- **Nivel 2 — Intermedio** (3): roles, collections + Ansible Galaxy, Vault + secret management.
- **Nivel 3 — Avanzado** (2): idempotencia profunda + patrones avanzados (delegate_to, run_once, serial, strategy, async), testing (Molecule, ansible-lint, CI).
- **Nivel 4 — Producción empresarial** (2): hybrid con Terraform/Packer + AWX/AAP, platform patterns (cuándo Ansible, cuándo *no*, immutable-first).

## 4. Entregables del curso

- Playbook del capstone que configura una VM Ubuntu (nginx reverse proxy + firewall + usuarios + hardening básico).
- Role propio para "FastAPI app en VM con systemd" + publicado como Galaxy role interno.
- Dynamic inventory contra AWS/GCP consumiendo tags.
- Pipeline GHA que: lint + Molecule test + aplica playbook contra VM dev; con approval contra prod.
- Imagen AMI construida con **Packer + Ansible** y usada por Terraform.
- ADR: dónde usar Ansible en el stack del capstone y dónde explícitamente *no*.

## 5. Evaluación

- **Conceptual**: diferenciar CM de IaC con ejemplos; qué hace idempotente a un módulo; por qué `shell:` no lo es; cuándo immutable supera a mutable.
- **Operativa**: playbook con roles, handlers, vault; dynamic inventory; test Molecule.
- **Arquitectónica**: elegir Ansible vs TF vs Docker vs Operator K8s para 5 escenarios distintos; defender la elección.

## 6. Recursos

A verificar en Fase 4:

- Documentación oficial `docs.ansible.com`.
- Ansible Galaxy y Automation Hub.
- `ansible-core` repo y collection ecosystem (`ansible.posix`, `community.general`, `community.aws`, `community.docker`, `kubernetes.core`).
- Molecule docs (`molecule.readthedocs.io`).
- *Ansible for DevOps* (Jeff Geerling) — referencia práctica.
- Packer docs (`developer.hashicorp.com/packer`).
- Event-Driven Ansible docs.
- AAP 2.x documentation.
