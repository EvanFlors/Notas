# Curso: Azure (diferencial contra AWS)

Roadmap especializado #16. **Curso diferencial**, no reimplementación completa. Asume **curso AWS** cursado y aprovecha ese modelo mental. Enfoque: **mapping conceptual + divergencias materiales + lo que realmente cambia en operación DevOps/Platform** (identidad con Entra ID, Management Groups, Azure Policy, Managed Identities, Container Apps, AKS).

## 1. Introducción

### Qué es

**Microsoft Azure** es la plataforma pública de Microsoft. Su jerarquía nativa es:

**Microsoft Entra ID (tenant)** → **Management Groups** → **Subscriptions** → **Resource Groups** → **Resources**.

- La **Subscription** es la unidad de aislamiento primaria (análogo funcional a la "cuenta" AWS, aunque la asociación con identidad vive aparte en Entra ID).
- Un **Resource Group** agrupa recursos relacionados dentro de una subscription (unidad de deploy y de deletion — borrar el RG borra todo lo que contiene). AWS *no tiene equivalente directo*; es un nivel adicional de agrupación.
- **Entra ID (ex Azure AD)** es la identidad: usuarios, grupos, service principals, managed identities, guest users. Un tenant puede abarcar varias subscriptions.
- La autorización se expresa con **Azure RBAC**: `role assignment` (role + principal + scope). El **scope** es jerárquico (tenant → mgmt group → subscription → RG → resource).

### Diferencias de modelo contra AWS (síntesis para transferencia)

| Dimensión | AWS | Azure |
|-----------|-----|-------|
| Jerarquía | Organization → OUs → Accounts → Resources | Entra ID Tenant → Management Groups → Subscriptions → **Resource Groups** → Resources |
| Unidad de aislamiento primaria | Account | **Subscription** |
| Agrupación adicional | — (OUs son organizacionales) | **Resource Group** (unidad de deploy y de eliminación) |
| Identidad | IAM (users, groups, roles, policies) | **Microsoft Entra ID** (users/groups/apps/SPNs/MIs) + **Azure RBAC** (role assignments) |
| Guardrails | **SCPs** (deny en la jerarquía Org) | **Azure Policy** (constraints) + **initiatives** (grupos de policies) |
| Credenciales efímeras | STS AssumeRole | **Managed Identities** (system-assigned o user-assigned) + **Workload Identity Federation** |
| OIDC desde CI/CD | OIDC → AWS role | **OIDC Federation** → Entra ID app registration + role assignment |
| Red | VPC regional | **VNet regional** (como AWS VPC); **VNet peering**, **Hub-Spoke**, **vWAN** |
| Firewall L3/L4 | SG + NACL | **NSG** (Network Security Group, stateful) + **ASG** (Application Security Group, por rol) + **Azure Firewall** |
| Compute (VMs) | EC2 + ASG | **Virtual Machine** + **VM Scale Sets (VMSS)** |
| Managed K8s | EKS | **AKS** (Azure Kubernetes Service) |
| Containers "sin K8s" | ECS / Fargate / App Runner | **Container Apps** (Dapr-friendly, scale-to-zero, serverless K8s abstracto) / **Container Instances (ACI)** / **App Service** |
| Serverless | Lambda | **Azure Functions** |
| Object storage | S3 | **Azure Storage** (Blob + File + Queue + Table en la misma Storage Account) |
| SQL managed | RDS/Aurora | **Azure SQL Database** / **Azure Database for PostgreSQL Flexible Server** |
| NoSQL managed | DynamoDB | **Cosmos DB** (multi-model: SQL, Mongo, Cassandra, Gremlin, Table) |
| Secrets | Secrets Manager | **Key Vault** (secrets + keys + certs) |
| Claves | KMS | **Key Vault** / **Managed HSM** |
| Observabilidad | CloudWatch + X-Ray + CloudTrail | **Azure Monitor** (Log Analytics + Metrics + **Application Insights** + **Activity Log** para audit) |
| CDN | CloudFront | **Azure Front Door** / **Azure CDN** (CDN clásico en deprecation parcial a favor de Front Door) |
| DNS | Route 53 | **Azure DNS** |
| TLS gestionado | ACM | **App Service Managed Cert** / **Front Door Managed Cert** / Key Vault cert |
| Multi-tenant governance | Organizations + Control Tower | **Management Groups** + **Azure Policy** + **Blueprints (en deprecación)** + **Cloud Adoption Framework (CAF) Landing Zones** |
| SSO humanos | IAM Identity Center | **Entra ID** nativo (es *la* identidad de Microsoft 365) |
| Compliance tooling | Config + Security Hub + GuardDuty | **Azure Policy** + **Microsoft Defender for Cloud** + **Sentinel** (SIEM) |

Puntos "sorprendentes" para alguien formado en AWS:
- **Resource Group** es un nivel extra sin análogo en AWS; es la unidad común de script/deploy/eliminación.
- **Entra ID** es compartido con Microsoft 365 — en orgs mixtas, los mismos grupos de M365 asignan permisos en Azure.
- **Managed Identities** son la vía ergonómica para que un recurso Azure (VM, Function, App Service, AKS pod via Workload Identity) tenga identidad sin secretos.
- **Azure Policy** opera por **constraints** (como GCP Org Policies) más que por listas de deny (como SCPs).
- **Container Apps** es un sweet spot que AWS no tiene exactamente (K8s administrado pero oculto; Dapr integrado; scale-to-zero).
- Nombres y UI cambian más que en AWS (ex Azure AD → Entra ID; Blueprints en deprecación; Azure DevOps vs GitHub Actions tensión interna).

### Historia (síntesis)

- **2008** — Microsoft anuncia Azure (como *Windows Azure*).
- **2014** — Satya Nadella CEO; "Microsoft loves Linux" → giro open source.
- **2016** — AKS (Azure Kubernetes Service).
- **2017** — Managed Identities (sin claves).
- **2020** — Private Link, Front Door Standard/Premium.
- **2022** — Azure AD rebrand → **Microsoft Entra ID**; Container Apps GA.
- **2023+** — Workload Identity GA en AKS; **Deployment Stacks** como mecanismo de IaC gestionado; Defender for Cloud consolidación.
- **2024+** — Policy as Code mejoras, Entra ID consolidación con M365, mejoras a OIDC federation.

### Problemas que resuelve

Los mismos de cualquier cloud público: infra on-demand, elasticidad, catálogo administrado, HA/multi-región, SOC/HIPAA/FedRAMP compliance.

Diferenciadores:
- Integración nativa con el stack **Microsoft 365 / Entra ID** (ideal en orgs Microsoft-first).
- **Hybrid cloud** maduro (**Azure Arc** gestiona recursos on-prem y multi-cloud como si fueran Azure).
- Catálogo fuerte en **enterprise data** (Synapse, Fabric, Power Platform).

### Casos de uso

- Hosting de apps web, APIs, pipelines.
- Workloads enterprise con compliance pesado (gov, salud, finanzas).
- Hybrid y multi-cloud via Arc.
- Equipos ya familiares con el stack Microsoft.

### Arquitectura general

```
┌──────────────────────────────────────────────────────┐
│ Microsoft Entra ID (tenant)                          │
│  - Usuarios/Grupos/Apps/SPNs/Managed Identities      │
│  - SSO, Conditional Access, PIM, MFA                 │
└──────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────┐
│ Management Groups (jerarquía)                        │
│  - Policy assignments heredadas                      │
└──────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────┐
│ Subscription (unidad de aislamiento + billing)       │
│   RBAC + Policy assignments                          │
│   ├── Resource Group (unidad de deploy/eliminación)  │
│   │    └── Resources (VM, VNet, Storage, AKS, …)     │
│   └── Resource Group ...                             │
└──────────────────────────────────────────────────────┘
```

Cada API Azure acepta `az` CLI, SDK, REST, PowerShell. OIDC federation convierte un identity provider externo (GitHub, GitLab, cualquier IdP) en principal que puede asumir un App Registration via `federated-credential`.

### Alternativas

Mismas del curso AWS; aquí interesa el **mapping**. Un ingeniero formado en AWS puede operar Azure con disciplina de "traducción"; la operación de prod requiere internalizar los diferenciadores (Entra ID, Resource Groups, Policy).

### Ventajas / limitaciones

**Ventajas**: integración con Entra ID / M365; hybrid cloud fuerte via Arc; Container Apps; Policy ergonómica; Defender for Cloud multi-cloud.

**Limitaciones / riesgos**:
- **Nomenclatura cambia** (Azure AD → Entra ID; muchos recursos renombrados). Hay documentación histórica contradictoria.
- **UI compleja**: Portal es poderoso pero vasto.
- **Pricing opaco** en algunos servicios (Front Door Premium, AKS cost sorpresa por log analytics).
- **Documentación** amplia pero fragmentada entre `learn.microsoft.com` nuevo y `docs.microsoft.com` legacy.
- **ARM templates / Bicep** son el nativo IaC (vs Terraform). Terraform funciona perfectamente pero algunos recursos nuevos llegan antes a Bicep.
- Catálogo menos amplio que AWS en algunas verticales (ML tooling, networking appliances).

### Relación con el programa

- Blanco opcional del capstone (comparar con AWS/GCP).
- **OIDC federation** desde GitHub Actions / GitLab se enseña igual que en AWS/GCP.
- **AKS** se integra con los cursos **kubernetes**, **helm**, **argocd-gitops**, **devsecops**.
- **Azure Monitor + Application Insights** complementa / sustituye el stack Prometheus/Grafana cuando la org es Microsoft-first.

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | **Curso AWS completo** (o conocimiento sólido de un cloud + redes + IAM). Curso **terraform**. |
| Recomendados | Curso **docker**, **kubernetes** ≥ Nivel 2, **github-actions**. |
| Complementarios | Experiencia previa en el stack Microsoft (opcional). |

## 3. Organización (4 niveles)

El curso tiene **10 módulos**. Deliberadamente compacto: solo cubre lo que es materialmente distinto o estratégicamente relevante.

- **Nivel 1 — Fundamentos diferenciales** (3): modelo global + Subscriptions/RGs + billing + `az` CLI, Entra ID + Azure RBAC + Managed Identities, VNet + NSG/ASG + Private Link + Hub-Spoke.
- **Nivel 2 — Compute, datos, secretos** (3): compute (VM/VMSS, **Container Apps**, Functions, App Service), datos (Azure SQL, Postgres Flexible, Cosmos DB, Storage), **Key Vault** (secrets + keys + certs) + Managed Identities como consumidor.
- **Nivel 3 — Avanzado** (2): **AKS** + Workload Identity + add-ons, **Azure Monitor** (Log Analytics + Metrics + Application Insights + Activity Log).
- **Nivel 4 — Producción empresarial** (2): multi-subscription + Management Groups + **Azure Policy** + **CAF Landing Zone**, DevSecOps (OIDC Federation + Defender for Cloud + ACR + supply chain).

## 4. Entregables del curso

- Subscription con MFA en identidades y budget con alerta.
- Resource Group con VNet multi-AZ, Cloud NAT equivalente (Azure NAT Gateway), Private Endpoints.
- App del capstone desplegada en **Container Apps** y, por separado, en **AKS** usando **Workload Identity**.
- Pipeline GHA → Azure vía **OIDC Federation** (sin service principal secrets).
- Baseline multi-sub con Management Groups + Azure Policy + CAF Landing Zone mínima.
- ADR Azure vs AWS vs GCP para un workload dado.

## 5. Evaluación

- **Conceptual**: traducir conceptos AWS↔Azure sin tabla; explicar scope jerárquico de role assignments; cuándo Managed Identity system vs user-assigned; cuándo Container Apps vs AKS vs App Service vs Functions.
- **Operativa**: desplegar workload en Container Apps y AKS; federar OIDC GHA→Azure; aplicar Azure Policy baseline.
- **Arquitectónica**: ADR cloud vs cloud; estrategia multi-subscription; política mínima con Azure Policy + Management Groups; estrategia hybrid con Arc (si aplica).

## 6. Recursos

A verificar en Fase 4:

- Documentación oficial: `learn.microsoft.com/azure`.
- Microsoft Cloud Adoption Framework (CAF) y Azure Landing Zones.
- Terraform `azurerm` provider; `azapi` provider para recursos nuevos.
- Azure Policy built-in definitions.
- Container Apps docs; Workload Identity for AKS docs.
- OIDC Federation docs (GitHub Actions, GitLab, cualquier IdP OIDC).
- Microsoft Defender for Cloud docs y multi-cloud support (AWS/GCP).
- Azure Arc docs (hybrid/multi-cloud management).
