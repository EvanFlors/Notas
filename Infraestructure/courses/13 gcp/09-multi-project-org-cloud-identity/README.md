# gcp-09 — Multi-project con Organization, Folders y Cloud Identity

## Identificación

- **ID:** `gcp-09-multi-project-org-cloud-identity`
- **Curso:** `gcp`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `gcp-01` (model/projects/billing), `gcp-02` (IAM core), curso AWS `aws-15` (contraste conceptual).

## Objetivo

Interiorizar cómo se opera un tenant GCP con **múltiples projects** gobernados por una jerarquía **Organization → Folders → Projects** con **Org Policies** como guardrails declarativos, **Cloud Identity** como fuente única de identidades humanas y **bindings basados en grupos**. Al terminar deberías poder diseñar — en papel — una organización pequeña (4–8 projects), decidir su estructura de folders, aplicar un baseline de **Org Policy constraints**, conectar **Cloud Identity** como IdP y bosquejar un **perímetro VPC Service Controls** que proteja los datos críticos, sin confundir una Org Policy con una binding IAM, ni un Folder con un Project.

## Alcance

Este módulo cubre:

- **Cloud Identity** (free vs premium) vs **Google Workspace** como base de usuarios y grupos; `cloudidentity.googleapis.com` groups vs Google Groups clásicos.
- **Resource Manager**: Organization (una por dominio), Folders anidables (hasta 10 niveles), Projects como unidad de aislamiento, herencia de IAM y de Org Policies de arriba hacia abajo.
- **Org Policy Service**: constraints *boolean* (`iam.disableServiceAccountKeyCreation`, `compute.vmExternalIpAccess`, `storage.publicAccessPrevention`) y *list* (`iam.allowedPolicyMemberDomains`, `compute.restrictVpcPeering`) con `inherit_from_parent`, `enforce`, `allowed_values`, `denied_values`.
- **Groups-based access** como práctica estándar: nunca `user:` directo en un binding; siempre `group:engineering-prod@dominio` creado en Cloud Identity.
- **Billing Account** separada del proyecto que la paga; patrón "una BA central paga N projects"; `Essential Contacts` para notificaciones críticas.
- **VPC Service Controls** (introductorio y conceptual): perímetros alrededor de projects sensibles para evitar exfiltración vía APIs de Google.
- **Security Command Center** (Standard vs Premium vs Enterprise) — mención, no laboratorio.
- Patrón **"una app = un project × un ambiente"** (dev/stg/prod cada uno en su project).
- Traducción de **SCP AWS → Org Policy GCP** y de **OU AWS → Folder GCP**.

Lo que **no** cubre (se verá después):

- WIF, Artifact Registry, Binary Authorization y FinOps avanzado → `gcp-10`.
- Terraform operativo (`project factory`, módulos reutilizables) — se referencia conceptualmente; el laboratorio en Terraform es parte de la Fase 4 del programa.
- GKE con Workload Identity → `gcp-07`.

Este módulo es **mayoritariamente conceptual + ADR + validación de YAML**. **No** se provisiona nada en una org real. Las dos actividades son análisis escritos y Org Policies/VPC-SC validadas estructuralmente; el único *tooling* es `bash`, `python3` (con `pyyaml`) y un editor Markdown.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-folders-tree-diagram/` — árbol anotado de un tenant GCP típico (Security + Shared + Workloads/dev-stg-prod + Sandbox).
  - `02-org-policy-anatomy/` — anatomía de una Org Policy: `constraint`, `booleanPolicy`, `listPolicy`, `inheritFromParent`, puntos de aplicación.
  - `03-cloud-identity-groups-and-wif/` — ciclo de vida de un grupo Cloud Identity y su uso en bindings; cómo encaja con WIF en `gcp-10`.
- **`activities/`** — dos actividades **independientes**:
  - `01-design-folder-structure-and-adr/` — diseñar la jerarquía para un escenario dado y escribir un **ADR** justificando folders, projects, org policies, grupos y perímetro VPC-SC.
  - `02-write-org-policy-baseline-and-validate/` — escribir 4 Org Policies del baseline y 1 perímetro VPC-SC en YAML, validarlos con `python3 + pyyaml` y documentar la intención.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar diferencia entre Org Policy y binding IAM; por qué el management (org admin) no hospeda workloads; por qué los bindings van a grupos, no a usuarios. |
| Diseño | Dibujar una jerarquía Organization → Folders → Projects para 4–8 projects con herencia de policies. |
| Guardrails | Nombrar y adjuntar las 4 Org Policies del baseline mínimo defendible. |
| Identidad | Diseñar el catálogo de grupos de Cloud Identity y mapearlos a roles por folder. |
| Red segura | Bosquejar un perímetro VPC-SC alrededor de datos regulados sin romper APIs globales. |

## Evaluación

1. Auditar una jerarquía existente y proponer las Org Policies mínimas (actividad 01, sección reflexión).
2. Traducir una SCP AWS concreta (`deny-regions`, `deny-leave-org`) a su Org Policy GCP equivalente (actividad 02).

## No se incluye

- Provisión real en una Organization. **Costos: 0 USD**.
- Pipelines de CI/CD aplicando los YAMLs — eso es Fase 4.
- Configuración detallada de Access Context Manager (solo bosquejo en VPC-SC).
