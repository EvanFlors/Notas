# az-06 — Key Vault y Managed Identities (consumer)

## Identificación

- **ID:** `az-06-key-vault-and-managed-identities-consumer`
- **Curso:** `azure`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `az-02` (Entra ID, RBAC, Managed Identities), curso AWS ≥ `aws-09` (Secrets Manager + KMS + rotación).

## Objetivo

Dominar **Azure Key Vault** como almacén unificado de **secrets**, **keys** y **certificates**, y consumirlo **sin credenciales embebidas** desde workloads modernos (Container Apps, App Service, AKS) usando **Managed Identities** más el modelo **RBAC data-plane** moderno (preferido sobre las *access policies* legacy).

Al terminar deberías poder:

- Decidir cuándo usar un **secret**, una **key** o un **certificate** en Key Vault.
- Justificar por escrito por qué **RBAC data-plane** gana a las *access policies* legacy en una organización moderna.
- Diseñar — en Terraform *plan-ready* — un Key Vault con **soft delete + purge protection**, una **User-Assigned Managed Identity** y un `role_assignment` del rol built-in **Key Vault Secrets User**.
- Describir el flujo de **certificado TLS con auto-renovación** vía issuer integrado y la **certificate policy** JSON asociada.

## Alcance

Este módulo cubre:

- **Key Vault**: tipos de recurso (`vault` estándar vs **Managed HSM** para FIPS 140-2 L3), SKU `standard` vs `premium` (HSM-backed por key), **soft delete** (obligatorio desde 2020) y **purge protection** (irreversible, obligatorio en prod).
- **Modelo de autorización**: **access policies** (legacy, por *principal*, hasta 1024 por vault) vs **Azure RBAC data-plane** (moderno, uniforme con el management plane, hereda por scope). Roles built-in: `Key Vault Secrets User`, `Key Vault Secrets Officer`, `Key Vault Crypto User`, `Key Vault Certificate Officer`.
- **Managed Identities como consumer**: **system-assigned** (vida ligada al recurso) vs **user-assigned** (recurso aparte, reutilizable). Receta estándar: MI del recurso + `Key Vault Secrets User` sobre el scope del vault.
- **Patrones de consumo**:
  - **Container Apps / App Service**: referencia directa `@Microsoft.KeyVault(SecretUri=...)` sin SDK en el código.
  - **AKS**: **Secrets Store CSI Driver** con el provider de Azure + Workload Identity.
  - **Azure Functions**: igual que App Service.
- **Certificates**: lifecycle completo (issuer integration con DigiCert/GlobalSign/self-signed, auto-renewal con `renew_before_expiry`, encadenado a Front Door / Application Gateway / Container Apps).
- **Rotación**: `azurerm_key_vault_secret.version` nuevo vs rotación con `event_grid` + Function + trigger de aplicación.

Lo que **no** cubre (se verá después):

- **Workload Identity en AKS** con *federated credentials* → `az-07`.
- **Defender for Key Vault** y auditoría de accesos → `az-08` + `az-10`.
- **Azure Policy** para forzar `purge_protection_enabled = true` en toda la org → `az-09`.

Este módulo es **mayoritariamente IaC + diseño**. **No** se provisiona nada en una suscripción real. Las dos actividades producen Terraform *plan-ready* + JSON (role assignment / certificate policy) + un `README-INTENT.md`. El único *tooling* requerido es `bash`, `jq`, `terraform fmt` (opcional) y un editor Markdown.

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones (Key Vault como servicio, soft delete, RBAC vs access policies, Managed Identities, patrones de consumo, certificates, rotación, troubleshooting).
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-key-vault-rbac-dataplane/` — HCL comentado: `azurerm_key_vault` con `enable_rbac_authorization = true` + `azurerm_role_assignment` del rol `Key Vault Secrets User` a una Managed Identity.
  - `02-container-app-reads-secret-with-mi/` — walkthrough: cómo un `azurerm_container_app` con `identity { type = "UserAssigned" }` referencia un secret con `@Microsoft.KeyVault(...)`.
  - `03-aks-csi-driver-kv/` — walkthrough del Secrets Store CSI Driver con el Azure Key Vault provider en AKS (sin provisionar AKS; se referencia `az-07`).
- **`activities/`** — dos actividades **independientes**:
  - `01-capstone-secrets-via-kv/` — diseñar un Key Vault + User-Assigned MI + role assignment para que el capstone (FastAPI) lea un secret. Produce Terraform `plan-ready`, un `role-assignment-kv-secrets-user.json` validable y `README-INTENT.md`.
  - `02-cert-auto-renewal/` — diseñar la **certificate policy** JSON de un cert TLS con auto-renovación (`renew_before_expiry = 30 días`, self-signed para dev) + Terraform `azurerm_key_vault_certificate` + `README-INTENT.md`.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué RBAC data-plane gana a access policies legacy; diferencia entre secret, key y certificate; por qué soft delete + purge protection son obligatorios en prod; qué hace una Managed Identity bajo el capó. |
| Operativa (sin infra) | Escribir Terraform HCL con `azurerm_key_vault` + `azurerm_user_assigned_identity` + `azurerm_role_assignment`; escribir un JSON de role assignment con `principalId`, `roleDefinitionId`, `scope` sintácticamente válido; escribir una `certificate_policy` JSON de Key Vault. |
| Arquitectónica | Decidir Container Apps vs AKS para el consumer; mapear roles built-in a cada tipo de workload; planificar rotación y purge en una org pequeña. |

## Criterios de evaluación

- Dado un HCL de `azurerm_key_vault`, identifica si usa RBAC o access policies legacy y propone migración.
- Lee un `role_assignment` y nombra el **principal**, el **scope** y el **role** con precisión.
- Justifica por qué el `principalId` de una MI User-Assigned es su `principal_id`, no su `client_id`.
- Nombra 3 roles built-in de Key Vault y para qué sirven.
- Entrega las dos actividades con sus validadores estructurales en verde (`0 issue(s)`).

## Entregables

- **Actividad 01**: `main.tf` + `variables.tf` + `role-assignment-kv-secrets-user.json` + `README-INTENT.md` justificando el diseño.
- **Actividad 02**: `main.tf` con `azurerm_key_vault_certificate` + `certificate-policy.json` + `README-INTENT.md` describiendo la auto-renovación.

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto, HCL y JSON. **No** se requiere subscription Azure activa, **no** se ejecuta `terraform apply`, **no** se crean secretos reales (los *dummies* son strings como `CHANGE-ME-DUMMY-NOT-A-REAL-SECRET`). Si en una fase posterior decides provisionar lo diseñado:

- **Key Vault SKU `standard`**: ~0.03 USD / 10k operaciones + ~0.03 USD / clave / mes para claves HSM-backed (en `premium`).
- **Managed Identity**: gratis.
- **Role assignments**: gratis.
- **Secrets Store CSI Driver**: gratis (es un componente open source instalado en AKS).

En un entorno de laboratorio pequeño suele quedar por debajo de 1 USD/mes, pero no es cero si se habilitan features premium (HSM, certs con issuer de pago).

## Siguiente módulo

→ `az-07-aks-and-workload-identity` — operar AKS con **Workload Identity** (federated OIDC) consumiendo Key Vault vía CSI Driver sin secretos de service principal.
