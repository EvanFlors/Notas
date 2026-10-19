# gcp-09 — Lección: multi-project con Organization, Folders y Cloud Identity

> 12 secciones. Mayoritariamente conceptual. Prerrequisitos: `gcp-01`, `gcp-02`, curso AWS `aws-15` (para contrastar).

---

## 1. Por qué multi-project y no un project "bien hecho"

En GCP el **project** es gratis de crear (sin coste base) y es la **unidad natural de aislamiento**: cada project tiene sus propias APIs habilitadas, sus propias cuotas, sus propios bindings IAM, su propia red por defecto, su propia línea de billing. A diferencia de AWS — donde abrir una cuenta implica un ciclo de email, verificaciones y, en organizaciones pequeñas, fricción real — en GCP crear un project es `gcloud projects create` y no cuesta nada hasta que se habilitan APIs facturables.

Esto cambia la economía del aislamiento: en GCP el patrón canónico es **"una app × un ambiente = un project"** (es decir, `checkout-dev`, `checkout-stg`, `checkout-prod` son tres projects distintos), no "una cuenta por app". El techo lo pone la gobernanza, no la ceremonia.

Los síntomas de "todo en un project" son los mismos que en AWS, con un matiz: el **blast radius por error de IAM** se contiene mejor si los recursos regulados viven en un project aparte, porque un `roles/editor` en el project de staging no toca prod.

> **Idea clave:** el project es el límite duro de aislamiento. La jerarquía Organization → Folders → Projects es el techo (lo que ninguna binding puede desbloquear). Cloud Identity es la puerta (cómo entran los humanos).

---

## 2. Resource Manager: Organization, Folders y Projects

**Resource Manager** modela una jerarquía estricta:

```
Organization (ejemplo.com)             ← una por dominio verificado
├── Folder: Security                   ← contenedor lógico, hasta 10 niveles
│   ├── Project: logging-prod
│   └── Project: security-audit
├── Folder: Shared
│   └── Project: shared-vpc-host
├── Folder: Workloads
│   ├── Folder: Prod
│   │   ├── Project: checkout-prod
│   │   └── Project: analytics-prod
│   ├── Folder: Stg
│   └── Folder: Dev
└── Folder: Sandbox
    └── Project: sandbox-shared
```

Reglas:

1. **Organization** es única por dominio y se crea automáticamente al provisionar Cloud Identity o Google Workspace sobre ese dominio.
2. **Folders** son contenedores lógicos, anidables hasta 10 niveles; su único propósito es agrupar projects para heredar IAM y Org Policies.
3. **Projects** son hojas: no se anidan projects dentro de projects. Un project puede moverse entre folders (`gcloud projects move`).
4. **Herencia**: una binding IAM en un folder aplica a todos los projects descendientes; una Org Policy aplicada a un folder aplica a toda la subrama (con `inheritFromParent` controlable).

> **Contraste AWS:** en AWS la **cuenta** es el límite y las OUs sirven para adjuntar SCPs. En GCP el **project** es el límite y los Folders sirven para heredar IAM y Org Policies. La forma del árbol es parecida; el nodo hoja es distinto (cuenta vs project).

---

## 3. Patrones típicos de folders

Un diseño por defecto defendible para una org pequeña a mediana:

| Folder | Qué va dentro | Guardrails típicos |
|--------|---------------|--------------------|
| `Security` | Projects de logging centralizado, SIEM, Security Command Center. | `storage.publicAccessPrevention=enforced`, `iam.disableServiceAccountKeyCreation=enforced`, `compute.vmExternalIpAccess=denyAll`. |
| `Shared` | Shared VPC host, Artifact Registry corporativo, DNS zone. | `compute.restrictSharedVpcHostProjects` restringido. |
| `Workloads/Prod` | Projects de cargas productivas (una app × project). | Baseline + `compute.requireOsLogin=enforced`, VPC-SC perimeter. |
| `Workloads/Stg` | Pre-prod, data real anonimizada. | Baseline. |
| `Workloads/Dev` | Experimentación de equipos. | Baseline + budget alerts más agresivas. |
| `Sandbox` | Juguete personal con budget hard cap. | Baseline + `compute.vmExternalIpAccess=denyAll` + budget caps bajos. |

**Nunca** hospedar cargas en el project que contiene las identidades de administración de la Organization: ese "org admin project" existe para hostear los Workload Identity Pools, los grupos del catálogo y los recursos de automatización, no la app de pagos.

---

## 4. Cloud Identity vs Google Workspace

GCP necesita una **fuente de identidades** para que existan usuarios y grupos vinculables en bindings IAM. Dos opciones:

- **Google Workspace** (de pago): incluye Gmail, Drive, Meet, Docs. Se usa por correo + colaboración; de regalo trae Cloud Identity.
- **Cloud Identity Free / Premium**: solo identidades y grupos, sin Gmail/Drive. Es la opción cuando la org usa Microsoft 365, Okta u otra suite y solo quiere "la base de usuarios de GCP".

Ambas:

- Crean una Organization al verificar el dominio DNS.
- Permiten crear **grupos** (`cloudidentity.googleapis.com/groups`) que son el objeto que se bindea en IAM: `group:engineering-prod@ejemplo.com`.
- Pueden federarse con un IdP externo (Okta, Entra ID) vía SAML + SCIM.

> **Importante:** el formato `group:` en bindings exige que el grupo exista en Cloud Identity. Un alias de Google Groups personal (`@googlegroups.com`) **no** sirve en bindings de recursos corporativos.

---

## 5. Groups-based access: nunca `user:` directo

La práctica estándar — y la que te exigirá cualquier auditor — es:

- **Prohibido** `user:alice@ejemplo.com` en una binding.
- **Obligatorio** `group:engineering-prod@ejemplo.com` donde la pertenencia de Alice al grupo es la que concede el acceso.

¿Por qué? Rotación de personas sin tocar IAM. Cuando Alice cambia de equipo, se la saca del grupo `engineering-prod` y se la mete en `data-eng`; la jerarquía de bindings no se toca. Esto desacopla **autorización** (los bindings, estables) de **membresía** (las personas, cambiantes).

Catálogo mínimo de grupos para una org pequeña:

| Grupo | Rol típico | A qué folder/project |
|-------|------------|----------------------|
| `gcp-org-admins@` | `roles/resourcemanager.organizationAdmin` | Organization (muy pocas personas, con MFA obligatorio). |
| `gcp-billing-admins@` | `roles/billing.admin` | Billing Account. |
| `gcp-security@` | `roles/iam.securityReviewer` + `roles/logging.viewer` | Organization. |
| `gcp-dev-engineers@` | `roles/editor` | Folder `Workloads/Dev`. |
| `gcp-prod-sre@` | Custom role (ver abajo) | Folder `Workloads/Prod`. |
| `gcp-breakglass@` | `roles/owner` sobre un project específico, con `Condition` por tiempo. | Project crítico, uso excepcional, auditado. |

---

## 6. Org Policy Service: constraints como declaraciones

**Org Policies** son el equivalente conceptual de las SCPs AWS, pero con un enfoque **declarativo**: en vez de "deniega estas acciones", declaras "este constraint vale esto" y GCP se encarga de rechazar llamadas que violen la declaración.

Formas:

- **Boolean constraints**: `iam.disableServiceAccountKeyCreation` (true/false), `compute.vmExternalIpAccess` con `denyAll`, `storage.publicAccessPrevention` (enforced/not-enforced).
- **List constraints**: `iam.allowedPolicyMemberDomains` (lista de customer IDs permitidos como principals), `compute.restrictVpcPeering` (lista de projects/orgs permitidos).

Anatomía YAML (versión v2 moderna, resource-oriented):

```yaml
name: organizations/123456789012/policies/iam.disableServiceAccountKeyCreation
spec:
  rules:
    - enforce: true
  inheritFromParent: false
  reset: false
```

Puntos de aplicación: Organization, Folder o Project. Se aplican de arriba hacia abajo; `inheritFromParent: true` suma restricciones del padre, `false` las ignora, `reset: true` vuelve al default de Google.

**Baseline defendible** para arrancar:

1. `iam.disableServiceAccountKeyCreation=enforced` en Organization — evita el anti-patrón "SA key en el repo".
2. `compute.vmExternalIpAccess=denyAll` en Organization (con excepciones por project si una VM necesita IP pública, p. ej. bastión).
3. `storage.publicAccessPrevention=enforced` en Organization — cero buckets abiertos al mundo.
4. `iam.allowedPolicyMemberDomains` restringido al customer ID de tu dominio — nadie fuera de la org puede ser agregado como principal.
5. (Opcional) `compute.restrictVpcPeering` para controlar peering fuera de la org.
6. (Opcional) `sql.restrictPublicIp=enforced` en folders productivos.

---

## 7. Billing Account y Essential Contacts

Una **Billing Account (BA)** es un objeto independiente del project; se enlaza a projects (`gcloud beta billing projects link`). Una BA puede pagar por N projects, un project solo puede estar enlazado a una BA.

Patrón canónico:

- **Una BA central** pagada por tarjeta corporativa, administrada por `gcp-billing-admins@`.
- Todos los projects del tenant la usan.
- Para cost allocation, cada project lleva labels (`cost_center`, `team`, `env`); el billing export a BigQuery los agrega.

**Essential Contacts** (`essentialcontacts.googleapis.com`) permite declarar quién recibe emails críticos (incidentes de seguridad, cambios de política, suspensiones). Debe estar poblado al menos para las categorías `BILLING`, `SECURITY`, `TECHNICAL`, `LEGAL`. Si no se configura, los emails llegan al owner del project — un single point of failure.

---

## 8. VPC Service Controls: perímetros contra exfiltración

**IAM** evita que principales no autorizados accedan a un recurso. **VPC Service Controls (VPC-SC)** evita que **datos regulados salgan** del perímetro definido, incluso cuando el principal tiene permisos. Es ortogonal a IAM; actúa en el plano de red + API.

Un **perímetro de servicio** envuelve uno o varios projects y declara:

- Qué APIs están protegidas (`restrictedServices`: típicamente `storage.googleapis.com`, `bigquery.googleapis.com`, `cloudkms.googleapis.com`).
- Qué `accessLevels` pueden entrar (p. ej. un rango de IP corporativa, o requerir device trust via Access Context Manager).
- Qué `ingress`/`egress rules` permiten tráfico cruzado entre perímetros (siempre explícito).

Resultado: si un atacante consigue credenciales de un service account con `roles/storage.admin` y trata de hacer `gcloud storage cp gs://bucket-sensible/foo /tmp` desde fuera del perímetro, la API responde `PERMISSION_DENIED` por **perimeter check**, aunque IAM diga que sí puede.

Perímetro mínimo típico para un folder `Workloads/Prod` que maneja datos regulados:

```yaml
name: accessPolicies/XXXXXX/servicePerimeters/prod_data_perimeter
title: prod_data_perimeter
status:
  resources:
    - projects/<project-number-of-checkout-prod>
    - projects/<project-number-of-analytics-prod>
  restrictedServices:
    - storage.googleapis.com
    - bigquery.googleapis.com
    - cloudkms.googleapis.com
  accessLevels:
    - accessPolicies/XXXXXX/accessLevels/corp_network
  vpcAccessibleServices:
    enableRestriction: true
    allowedServices:
      - RESTRICTED-SERVICES
```

> **Nota de números de project:** `projects/<project-number>` usa el **número**, no el ID. En diseños en papel se escribe `projects/<project-number-of-...>` como placeholder; nunca pegues un número real de un tenant ajeno.

---

## 9. Diferencia Org Policy vs IAM Deny Policies vs IAM allow bindings

Tres planos distintos, se evalúan en orden:

1. **Org Policy** (declarativo, servicio-level): "en esta subrama, los buckets no pueden ser públicos". Nadie puede allowear por encima.
2. **IAM Deny Policy** (específico de principal, nuevo plano): "este principal no puede ejecutar `storage.objects.delete` sobre `bucket-prod`". Bloquea incluso si hay allow binding.
3. **IAM Allow Binding** (`role → members` en un recurso): da permiso. Herencia hacia abajo.

Evaluación conceptual: Org Policy limita el *contrato del servicio*; Deny Policies vetan a principales concretos; Allow Bindings conceden lo restante.

> **Mapeo con AWS:** SCP ≈ Org Policy *más* IAM Deny Policy. GCP separa los dos planos; AWS los funde en SCP + resource policy.

---

## 10. Patrones de projects por workload

Decisión concreta por workload:

- **`checkout`** (crítico, PCI-light): tres projects (`checkout-dev`, `checkout-stg`, `checkout-prod`), cada uno con su VPC, su Cloud SQL, sus secrets. Prod dentro del perímetro VPC-SC `prod_data_perimeter`.
- **`analytics`** (interno, no toca datos de pago): puede empezar en un único project `analytics-shared` dentro de `Workloads/Dev`; cuando crezca, se parte en `-dev`/`-prod`.
- **CI/CD / tools**: en un project `tools-shared` dentro de `Shared`, no en el org admin.
- **Shared VPC host**: project dedicado dentro de `Shared`, sin workloads; solo IPs, firewall rules y attach de projects *service*.

Regla heurística:

> Si el workload tiene **datos regulados** o **disponibilidad crítica**, cada ambiente va a un project separado. Si no, puedes empezar con un project por workload y partir después.

---

## 11. Checklist de bootstrap de la organización

Secuencia mínima defendible al arrancar una org GCP:

1. Verificar dominio y provisionar **Cloud Identity Free** (o Workspace si ya existe).
2. Reclamar la **Organization** (`gcp-org-admins@` como organization admin, con MFA obligatorio).
3. Crear la estructura mínima de folders: `Security`, `Shared`, `Workloads/{Prod,Stg,Dev}`, `Sandbox`.
4. Crear los grupos mínimos en Cloud Identity: `gcp-org-admins@`, `gcp-billing-admins@`, `gcp-security@`, `gcp-breakglass@`.
5. Aplicar el **baseline de Org Policies** en Organization (4 constraints de §6).
6. Crear la **Billing Account** y enlazar un primer project de prueba.
7. Habilitar **Essential Contacts** para las 4 categorías obligatorias.
8. Habilitar **Cloud Audit Logs** (Admin Activity es gratis y siempre on; Data Access se activa explícitamente para los projects regulados).
9. (Opcional pero recomendado) Activar **Security Command Center Standard** a nivel de Organization.
10. Documentar todo en un ADR, versionado en Git — este es el entregable del módulo.

---

## 12. Antipatrones comunes y cómo evitarlos

| Antipatrón | Por qué duele | Cómo evitarlo |
|------------|---------------|---------------|
| Bindings a `user:` directos | Rotación de personas rompe acceso o deja permisos huérfanos. | Siempre `group:` desde Cloud Identity. |
| Service Account keys descargadas | Credencial estática que se filtra en Git o CI logs. | `iam.disableServiceAccountKeyCreation=enforced` + impersonation o WIF. |
| Workloads en el org admin project | Cualquier error de IAM compromete toda la organización. | Reservar el project admin para automatización; workloads en folders operativos. |
| Un folder plano `Projects` con todos los projects | No se puede diferenciar policy entre dev y prod. | Al menos tres folders operativos (`Prod`, `Stg`, `Dev`). |
| Permitir cualquier dominio como principal | Alguien agrega a `attacker@gmail.com` como owner. | `iam.allowedPolicyMemberDomains` restringido al customer ID propio. |
| Confundir Org Policy con binding IAM | "Pongo un Deny en la policy del bucket" cuando lo que se necesita es un constraint org-wide. | Aprender los tres planos (§9) y aplicar el correcto. |
| VPC-SC "a modo copy-paste" sin perímetros bien definidos | Rompe CI/CD y lanza falsos positivos. | Diseño en papel primero (ADR), *dry-run mode* antes de `enforce`. |

---

## Preguntas de autoevaluación

1. ¿Por qué un project GCP es más barato de aislar que una cuenta AWS? ¿Qué consecuencia tiene en la decisión "una app por project vs una app por N projects"?
2. ¿Qué pasa si pones una Org Policy `storage.publicAccessPrevention=enforced` en la Organization y luego alguien intenta hacer un bucket público en un project hoja?
3. ¿Qué pasa si el grupo `gcp-prod-sre@` no existe en Cloud Identity pero lo pones en un binding `roles/compute.admin` sobre un project?
4. ¿Por qué un perímetro VPC-SC sin `accessLevels` ni `ingressRules` puede dejar roto el `gcloud` del propio equipo de ops?
5. Traduce una SCP AWS `deny-regions` que limita a `eu-west-1`/`eu-central-1` a la Org Policy GCP equivalente. ¿Qué constraint usarías?

> Respuestas y referencia completa en `activities/01-design-folder-structure-and-adr/solution/REFERENCE.md`.
