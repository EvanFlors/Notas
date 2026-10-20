# az-09 — Multi-subscription con Management Groups, Azure Policy y Landing Zone (CAF)

## Identificación

- **ID:** `az-09-multi-subscription-management-groups-azure-policy-landing-zone`
- **Curso:** `azure`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `az-01` (modelo tenant/subscription/RG), `az-02` (Entra ID + RBAC + Managed Identities), `az-03` (VNet/NSG).

## Objetivo

Interiorizar cómo se opera un tenant Azure con **múltiples subscriptions** gobernadas de forma central mediante **Management Groups**, un baseline de **Azure Policy** y la estructura **CAF Landing Zone** (Enterprise Scale). Al terminar deberías poder diseñar — en papel — la jerarquía de MGs para una organización pequeña (3–5 subscriptions), decidir el patrón `Platform + Landing Zones + Sandbox + Decommissioned`, aplicar un baseline mínimo de policies (`deny locations`, `deny public IP`, `audit diagnostic settings`) y entender por qué una Azure Policy con efecto `deny` es el equivalente conceptual de una SCP de AWS Organizations.

## Alcance

Este módulo cubre:

- **Management Groups**: raíz (`Tenant Root Group`), jerarquía anidada (soft-limit 6 niveles), herencia de RBAC y de policies, patrón CAF Enterprise Scale.
- **Azure Policy**: `policyDefinition` (regla individual con `if/then`, efectos `audit`, `deny`, `append`, `modify`, `deployIfNotExists`, `auditIfNotExists`), **initiatives** (grupos de policies), scope de asignación (MG/Subscription/RG), exemptions con TTL.
- **CAF Landing Zone / Enterprise Scale**: estructura canónica (`Platform` con `Identity + Management + Connectivity`; `Landing Zones` con `Corp + Online`; `Sandbox`; `Decommissioned`), separación entre **plataforma** y **aplicaciones**.
- **Deployment Stacks** como sustituto moderno de **Blueprints** (deprecados).
- Interacción con **PIM** (Privileged Identity Management) y **Microsoft Entra ID** para accesos elevados temporales.
- Comparación 1:1 con AWS: `AWS Organizations` ↔ `Management Groups`, `OU` ↔ `MG anidado`, `SCP Deny` ↔ `Azure Policy effect deny`, `Control Tower` ↔ `Enterprise Scale Reference Implementation (ES ALZ)`.

Lo que **no** cubre (se verá después):

- Los controles DevSecOps sobre esta base (OIDC GHA → Entra ID, Defender, firma de imágenes) → `az-10`.
- Terraform operativo para esta estructura (`avm/ptn/alz` módulos CAF Verified) — se referencia pero el laboratorio en Terraform es parte de la Fase 4.
- Networking Hub-Spoke centralizado como parte de la LZ Platform (visto en `az-03`).

Este módulo es **mayoritariamente conceptual + ADR + validación estructural de JSON**. **No** se provisiona nada en un tenant real. Las dos actividades son análisis escritos y definiciones de Azure Policy validadas estructuralmente; el único *tooling* es `bash`, `jq`, `python3` y un editor Markdown.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-mg-hierarchy-diagram/` — árbol ASCII anotado de una jerarquía CAF Enterprise Scale (`Platform + Landing Zones + Sandbox + Decommissioned`).
  - `02-azure-policy-anatomy/` — anatomía de una `policyDefinition`: `mode`, `parameters`, `policyRule.if/then`, efectos `audit`/`deny`/`deployIfNotExists`; comparación con una SCP.
  - `03-caf-landing-zone-starter/` — descripción de la *reference implementation* ALZ: qué MGs crea, qué policies asigna por defecto, qué subscriptions bootstrapea.
- **`activities/`** — dos actividades **independientes**:
  - `01-design-mg-structure-and-adr/` — diseñar la jerarquía de MGs para un escenario dado y escribir un **ADR** justificando MGs, subscriptions, policies y modelo de acceso.
  - `02-write-azure-policy-baseline-and-validate/` — escribir 3 `policyDefinition` del baseline (`policy-deny-locations`, `policy-deny-public-ip`, `policy-audit-diagnostic-settings`) en JSON y validarlas estructuralmente.
- **`resources/links.md`** — referencias oficiales y lecturas (CAF, ALZ, Azure Policy, Deployment Stacks).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre `Azure Policy` y `RBAC role assignment`; por qué el `Tenant Root Group` no debe hospedar workloads; por qué una `initiative` es un contenedor y no una policy individual. |
| Operativa (sin infra) | Diseñar una jerarquía de MGs razonando trade-offs; escribir una `policyDefinition` sintácticamente correcta; mapear grupos de Entra ID a roles y a scopes. |
| Arquitectónica | Decidir el patrón CAF ALZ vs una jerarquía custom; integrar PIM para elevaciones JIT; traducir una SCP de AWS a una Azure Policy equivalente. |

## Criterios de evaluación

- Dado un diagrama de MGs, identifica qué subscription es `management`, cuáles son `platform`, cuáles son `landing zones`.
- Lee una Azure Policy y explica correctamente qué efecto aplica y a qué recursos.
- Justifica por qué un `role assignment` con `Contributor` **no** evade una Azure Policy con efecto `deny`.
- Nombra 3 policies del baseline estándar y qué protegen.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- **ADR** `ADR-MG-STRUCTURE.md` con decisión de jerarquía de MGs, subscriptions, policies y modelo de acceso (sale de la actividad `01`).
- Tres **Azure Policy definitions** en JSON válido con nombres `policy-deny-locations.json`, `policy-deny-public-ip.json`, `policy-audit-diagnostic-settings.json` (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto y JSON. No se requiere tenant Azure activo ni ninguna subscription. Si en una fase posterior decides provisionar lo diseñado:

- **Management Groups** y **Azure Policy**: gratis (el motor de evaluación no cobra).
- **Microsoft Entra ID** (free tier): gratis para funcionalidad base. PIM requiere **Entra ID P2** (~9 USD/user/mes).
- **CAF Enterprise Scale Landing Zone**: la plantilla y el deploy son gratis; los recursos que levanta (Log Analytics, Azure Firewall, Private DNS Zones, etc.) **sí** cobran. En un tenant pequeño real suele estar entre **50 y 300 USD/mes** por el Azure Firewall solo, si lo activas.

## Siguiente módulo

→ `az-10-devsecops-oidc-defender-acr-supply-chain` — DevSecOps aterrizado sobre esta base: OIDC GitHub Actions → Entra ID federated credential, Defender for Cloud, ACR Premium con cosign, Deployment Stacks.
