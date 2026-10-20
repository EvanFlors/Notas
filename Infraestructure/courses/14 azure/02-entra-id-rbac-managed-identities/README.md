# az-02 — Microsoft Entra ID, Azure RBAC y Managed Identities

## Identificación

- **ID:** `az-02-entra-id-rbac-managed-identities`
- **Curso:** `azure`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** `az-01` (tenant/subscription/RG + `az` CLI), curso AWS ≥ `aws-02` (IAM core), `aws-06` (trust policies / roles).

## Objetivo

Dominar el triángulo **identidad + autorización + credencial efímera** en Azure: **Microsoft Entra ID** como directorio, **Azure RBAC** como motor de autorización (role assignment = role + principal + scope) y **Managed Identities** como forma preferida de dar credenciales a workloads sin almacenar secretos. Al terminar deberías poder leer una role assignment y predecir qué permite, escribir un rol *custom* mínimo en JSON, y defender por escrito por qué una Managed Identity es casi siempre preferible a un Service Principal con client secret.

## Alcance

Este módulo cubre:

- **Microsoft Entra ID** (ex Azure AD): tenant, usuarios, grupos, **app registrations** (identidad de workloads externos — equivalente conceptual a una OAuth app), **service principals** (instancia de un app registration en un tenant), **managed identities** — **system-assigned** (vive y muere con el recurso) vs **user-assigned** (recurso aparte reasignable).
- **Azure RBAC**: `role assignment` = (role + principal + **scope**); scope jerárquico (Management Group → Subscription → RG → Resource); roles **built-in** (`Owner`, `Contributor`, `Reader`, `Storage Blob Data Reader`, `Key Vault Secrets User`...); **custom roles** en JSON con `actions`/`notActions`/`dataActions`/`notDataActions` y `assignableScopes`.
- Patrón de **least privilege**: preferir roles de datos (`Storage Blob Data Reader`) sobre roles amplios (`Reader` + legacy keys); preferir **groups-based** assignments; evitar asignar al usuario individual.
- **Conditional Access** y **MFA** (contexto breve) + **Privileged Identity Management (PIM)** para elevación JIT.
- **Managed Identities** aplicadas: adjuntar MI a una VM / Container App / Function; token obtenido vía IMDS sin secreto en código; evitar **client secrets** en Service Principals; cuándo sí hace falta un SPN (por ejemplo, workloads fuera de Azure que no pueden usar OIDC Federation).
- **Mental mapping AWS → Azure**: IAM user ≈ Entra ID user; IAM role (assumible) ≈ app registration + service principal; IAM role attached to EC2 (instance profile) ≈ Managed Identity attached al recurso; IAM policy ≈ role definition; attached policy ≈ role assignment en un scope.

Lo que **no** cubre (se verá después):

- Secretos y rotación en Key Vault (`az-06`).
- Workload Identity en AKS (OIDC K8s SA ↔ Entra ID app) — `az-07`.
- Guardrails tenant-wide con Azure Policy (`deny effects`, equivalente SCP) — `az-09`.
- OIDC Federation GitHub Actions → Entra ID — `az-10`.

Este módulo es **mayoritariamente conceptual + JSON + Terraform estático** (plan y walkthrough, sin `apply`). **No** se provisiona nada en un tenant real. Las dos actividades son análisis estructurado y validadores de JSON/HCL; el único *tooling* es `bash`, `jq`, `python3` y opcionalmente un editor Markdown.

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones (del tenant al token IMDS).
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-role-assignment-at-rg-scope/` — anatomía de un role assignment con snippets `az`/Terraform y la fórmula role + principal + scope.
  - `02-managed-identity-vm-to-keyvault/` — flujo end-to-end: VM con system-assigned MI → `Key Vault Secrets User` en el scope del vault → `GET /secrets` sin secreto en el código.
  - `03-custom-role-json/` — anatomía de un custom role: `actions` vs `dataActions`, `notActions`, `assignableScopes`, cuándo custom vs built-in.
- **`activities/`** — dos actividades **independientes**:
  - `01-least-privilege-storage-reader/` — escribir el *custom role definition* mínimo que permita leer blobs de una storage account específica (sin listar claves, sin otras acciones), validarlo con `jq`/`python`, documentarlo.
  - `02-mi-vs-sp-with-secret/` — producir un **plan Terraform** (sin `apply`) + walkthrough comparando (A) VM con user-assigned MI que lee Key Vault y (B) Service Principal con client secret como anti-patrón, justificando por qué (A) gana.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre app registration, service principal y managed identity; por qué `role assignment` es la unidad real de autorización; por qué `dataActions` existe aparte de `actions`. |
| Operativa (sin infra) | Escribir un custom role JSON válido con el mínimo necesario; leer un role assignment y decir qué permite; dibujar el flujo de token para una MI → Key Vault. |
| Arquitectónica | Traducir una IAM policy AWS a role assignments Azure equivalentes; defender MI sobre SPN+secret con argumentos verificables (rotación, surface area, auditoría). |

## Criterios de evaluación

- Dada una role assignment (role + principal + scope), identifica correctamente qué puede/no puede hacer el principal.
- Lee un custom role JSON y explica el efecto exacto de `actions`, `notActions`, `dataActions`, `notDataActions`.
- Justifica por escrito por qué el `scope` jerárquico (MG → Sub → RG → resource) es más restrictivo cuanto más bajo bajas.
- Nombra 3 roles built-in de datos (p. ej. `Storage Blob Data Reader`, `Key Vault Secrets User`, `Cosmos DB Account Reader`) y para qué sirven.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- **Custom role JSON** (`role-storage-blob-reader.json`) + variante con `condition` (`role-storage-blob-reader-with-condition.json`) + `README-INTENT.md` que explique por qué cada campo (sale de la actividad `01`).
- **Terraform plan + walkthrough** (`main.tf`, `variables.tf`, `README-INTENT.md`) comparando MI vs SPN+secret (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto, JSON y HCL. No se requiere subscription Azure activa. Si en una fase posterior decides materializar lo diseñado:

- **Entra ID** (usuarios, groups, app registrations, service principals): gratis en el plan Free (hasta ciertos límites); funcionalidades premium (P1/P2, Conditional Access avanzado, PIM) requieren licencia.
- **Azure RBAC** y **role assignments**: gratis.
- **Managed Identities**: gratis.
- Los recursos *consumidores* (VM, Key Vault, Storage) sí cobran — nada de eso vive en este módulo.

## Siguiente módulo

→ `az-03-vnet-nsg-asg-private-link-hub-spoke` — red regional segura (VNet + NSG + ASG + Private Endpoints) sobre la que apoyaremos los módulos de compute y datos.
