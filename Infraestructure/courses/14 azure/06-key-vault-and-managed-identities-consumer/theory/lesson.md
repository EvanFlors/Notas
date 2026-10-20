# az-06 — Lección: Key Vault y Managed Identities (consumer)

> 10 secciones. Mayoritariamente conceptual + HCL de ejemplo. Prerrequisitos: `az-01`, `az-02`, curso AWS ≥ `aws-09`.

---

## 1. Por qué Key Vault y no "variables de entorno con el secret"

El error de arranque más común con Azure es pegar el secret en una *app setting* del App Service, o — peor — en un `terraform.tfvars` que acaba commiteado. Funciona hasta que:

1. Alguien hace `az webapp config appsettings list` y el secret aparece en claro.
2. El `tfvars` se sube al repo privado y luego el repo se vuelve público.
3. Rotar implica un deploy manual coordinado con 4 equipos.
4. Auditoría pregunta "¿quién leyó este secret el 12 de agosto?" y nadie puede responder.

**Key Vault** resuelve esto siendo un **vault centralizado** con tres propiedades que ninguna app setting tiene:

- **Control de acceso por identidad** (Azure RBAC o access policies), auditado en Activity Log.
- **Soft delete + purge protection**: borrar un secret no lo borra; hay 7–90 días de recuperación.
- **Rotación** sin re-deploy: versión nueva del secret → la app la relee en el siguiente arranque (o en caliente con reload).

Equivalencia mental con AWS: **Secrets Manager** ≈ secrets, **KMS** ≈ keys, **ACM** ≈ certificates. Key Vault **unifica los tres** bajo un único recurso.

---

## 2. Tipología: `vault` estándar vs **Managed HSM**

Azure ofrece dos *flavors*:

| Dimensión | `azurerm_key_vault` (SKU `standard`/`premium`) | `azurerm_key_vault_managed_hardware_security_module` |
|-----------|-------------------------------------------------|-------------------------------------------------------|
| Garantía FIPS | 140-2 L1 (standard) / L2 (premium HSM-backed) | **140-2 L3** |
| Scope | secrets + keys + certificates | **solo keys** (BYOK/HYOK) |
| Precio base | ~0 USD base + operaciones | varios cientos USD/mes |
| Caso típico | 99% de workloads | regulación financiera dura, salud sensible |

En este curso trabajamos con `azurerm_key_vault` SKU `standard` — suficiente para el capstone.

---

## 3. Soft delete + purge protection: no son opcionales

Desde febrero 2020, **soft delete es `true` por defecto y no se puede deshabilitar**. Lo que sí puedes (y debes en prod) habilitar explícitamente:

```hcl
resource "azurerm_key_vault" "main" {
  name                       = "kv-capstone-dev"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 90    # 7..90, en prod usa 90
  purge_protection_enabled   = true  # irreversible, no se puede desactivar
}
```

- **Soft delete**: al borrar el vault o un secret, queda en "deleted state" N días. Puedes `recover` (lo revive) o `purge` (lo borras definitivamente).
- **Purge protection**: **nadie** puede `purge` antes de que termine el periodo de retención. Es **irreversible**: una vez habilitada, no se puede desactivar. Por eso Azure Policy prod obliga `purge_protection_enabled = true`.

> **Trampa clásica**: en dev dejas `purge_protection_enabled = true` y luego `terraform destroy` falla porque no puede borrar el vault "de verdad". En dev, déjalo `false`. En prod, siempre `true`.

---

## 4. RBAC data-plane vs access policies legacy

Hay **dos modelos** de autorización sobre los datos del vault (secrets, keys, certs):

### 4.1 Access policies (legacy)

Cada vault tiene una lista interna de hasta **1024** access policies. Cada policy = (object_id de un principal, permisos sobre secrets/keys/certs).

```hcl
# NO uses esto en diseños nuevos
resource "azurerm_key_vault" "legacy" {
  # ...
  enable_rbac_authorization = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.app.principal_id

    secret_permissions = ["Get", "List"]
  }
}
```

Problemas:

- La lista está **dentro** del recurso vault — mal diffs, mal en IaC colaborativa.
- Separada del modelo RBAC estándar — otro mental model.
- Granularidad limitada a los permisos predefinidos (`Get`, `List`, `Set`, …).

### 4.2 Azure RBAC data-plane (moderno, preferido)

Se marca `enable_rbac_authorization = true` y los permisos se dan con `azurerm_role_assignment` como cualquier otro recurso:

```hcl
resource "azurerm_key_vault" "modern" {
  # ...
  enable_rbac_authorization = true
  # (sin access_policy)
}

resource "azurerm_role_assignment" "app_reads_secrets" {
  scope                = azurerm_key_vault.modern.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}
```

Ventajas:

- **Herencia por scope**: puedes asignar a RG / Subscription y heredar.
- **Catálogo de built-in roles** rico y granular por tipo de dato:
  - `Key Vault Secrets User` — Get secret.
  - `Key Vault Secrets Officer` — CRUD secret.
  - `Key Vault Crypto User` — operaciones criptográficas sobre keys.
  - `Key Vault Crypto Officer` — gestionar keys.
  - `Key Vault Certificate Officer` — gestionar certs.
  - `Key Vault Reader` — ver metadata (no leer valores).
- **Mismo tooling** que para el management plane: `az role assignment create`, `role.yaml`, Terraform.

> **Regla de este curso**: todo diseño nuevo usa `enable_rbac_authorization = true`. Access policies solo aparecen en lecciones de migración.

---

## 5. Managed Identities como consumer

Repaso rápido (ya cubierto en `az-02`):

- **System-assigned**: la crea Azure al asignar `identity { type = "SystemAssigned" }` a un recurso (VM, Container App, Function, App Service). **Vive y muere con el recurso**. Un recurso = una SA MI.
- **User-assigned**: recurso Azure independiente (`azurerm_user_assigned_identity`). Puede adjuntarse a **varios** recursos y sobrevivirlos.

Para consumir Key Vault, la receta estándar es:

1. Crear una **User-Assigned Managed Identity**.
2. Adjuntarla al recurso cliente (Container App, Function, App Service, VM, AKS pod via Workload Identity).
3. Asignarle `Key Vault Secrets User` **sobre el scope del vault**.
4. En el código, pedir token a `IDENTITY_ENDPOINT` (automático con `DefaultAzureCredential` del SDK o con la sintaxis `@Microsoft.KeyVault(...)` en App Service/Container Apps).

> **Trampa clásica**: usar `client_id` en lugar de `principal_id` en el `role_assignment`. El `principal_id` (= `object_id` del service principal subyacente) es lo que RBAC necesita. El `client_id` es solo para la ruta de autenticación del SDK.

---

## 6. Patrón A — Container Apps / App Service con referencia directa

El framework de App Service soporta la sintaxis especial `@Microsoft.KeyVault(SecretUri=...)` en las *app settings*. Lo mismo aplica a Container Apps vía `secret` block con `key_vault_secret_id`.

Ejemplo HCL (Container Apps):

```hcl
resource "azurerm_container_app" "api" {
  name                         = "ca-capstone"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  secret {
    name                = "db-connection-string"
    identity            = azurerm_user_assigned_identity.app.id
    key_vault_secret_id = azurerm_key_vault_secret.db_conn.versionless_id
  }

  template {
    container {
      name   = "api"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      env {
        name        = "DB_CONN"
        secret_name = "db-connection-string"
      }
    }
  }
}
```

El flujo bajo el capó:

1. Azure sabe que `DB_CONN` viene de un `secret` que referencia un `key_vault_secret_id`.
2. En el arranque del contenedor, usa la User-Assigned MI para pedir un token a Entra ID (`.default` audience de `vault.azure.net`).
3. Con ese token hace `GET` al secret vía REST.
4. Inyecta el valor como variable de entorno `DB_CONN`.
5. **Nunca** aparece el secret en claro en el HCL ni en Activity Log del Container App — solo en el audit del vault.

> `versionless_id` vs `id`: el primero apunta al secret sin pinnear versión → cuando rotas, la próxima lectura trae la versión nueva. Si pinneas versión (`.id`), tendrás que redeployar al rotar.

---

## 7. Patrón B — AKS con Secrets Store CSI Driver

En AKS la receta cambia: el `@Microsoft.KeyVault(...)` no existe. Se usa el **Secrets Store CSI Driver** con el **Azure Key Vault provider** instalado como add-on gestionado:

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-capstone
  namespace: capstone
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    clientID: "00000000-0000-0000-0000-000000000000"   # client_id de la User-Assigned MI (dummy en docs)
    keyvaultName: "kv-capstone-dev"
    cloudName: ""
    objects:  |
      array:
        - |
          objectName: db-connection-string
          objectType: secret
    tenantId: "00000000-0000-0000-0000-000000000000"   # tenant_id dummy en docs
```

Y en el pod se monta como volumen:

```yaml
volumes:
  - name: secrets
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: azure-kv-capstone
```

Autenticación: via **Workload Identity** (OIDC federation entre el ServiceAccount de K8s y la User-Assigned MI). Esto es tema de `az-07`; aquí solo lo mencionamos conceptualmente.

---

## 8. Certificates: lifecycle y auto-renovación

Un *certificate* en Key Vault **no** es "un secret que resulta ser un PEM". Es un recurso de primera clase con:

- **Issuer**: `Self` (self-signed, dev) o integrado (`DigiCert`, `GlobalSign`, `Unknown` para issuers externos manuales).
- **Policy**: define algoritmo, key size, usos, validez, política de renovación.
- **Versioning**: cada renovación crea una versión nueva.
- **Secret counterpart**: cada cert tiene un secret asociado (PEM/PFX) y una key asociada — las tres entidades están sincronizadas.

Ejemplo de policy JSON (es lo que entra en `azurerm_key_vault_certificate.certificate_policy`):

```json
{
  "issuerParameters": {
    "name": "Self"
  },
  "keyProperties": {
    "exportable": true,
    "keySize": 2048,
    "keyType": "RSA",
    "reuseKey": false
  },
  "lifetimeActions": [
    {
      "action": { "actionType": "AutoRenew" },
      "trigger": { "daysBeforeExpiry": 30 }
    }
  ],
  "secretProperties": {
    "contentType": "application/x-pkcs12"
  },
  "x509CertificateProperties": {
    "keyUsage": ["digitalSignature", "keyEncipherment"],
    "subject": "CN=capstone.example.com",
    "subjectAlternativeNames": {
      "dnsNames": ["capstone.example.com", "www.capstone.example.com"]
    },
    "validityInMonths": 12
  }
}
```

Puntos clave:

- `lifetimeActions[].action.actionType = "AutoRenew"` + `trigger.daysBeforeExpiry = 30` → Key Vault **renueva solo** 30 días antes del expiry.
- Para issuers integrados (DigiCert/GlobalSign) la renovación sale al CA real.
- Para `Self` la renovación es local (útil solo en dev).

El cert renovado conserva el mismo *certificate name* → App Gateway, Front Door y Container Apps apuntan al nombre y recogen la versión nueva sin re-deploy.

---

## 9. Rotación de secrets

Dos modelos operativos:

### 9.1 Rotación manual con `versionless_id`

Operador o pipeline sube una versión nueva (`az keyvault secret set` o `azurerm_key_vault_secret`). Las apps que referencian `versionless_id` la leen en el siguiente ciclo (arranque de pod/Container App o reload en caliente si la app implementa polling).

### 9.2 Rotación automatizada con Event Grid

Key Vault emite eventos (`Microsoft.KeyVault.SecretNearExpiry`, `Microsoft.KeyVault.SecretNewVersionCreated`). Se enganchan con Event Grid → Azure Function → la function rota el secret real en el backend (p. ej. `AlterUserPassword` en Postgres) y escribe el nuevo valor en Key Vault.

En el capstone, el patrón 9.1 es suficiente. 9.2 se cubre en `az-08`.

---

## 10. Troubleshooting rápido

Síntomas comunes y causa raíz:

| Síntoma | Causa raíz probable |
|---------|---------------------|
| `Caller is not authorized to perform action on resource` al leer un secret desde la app | MI tiene el rol asignado a scope equivocado (RG en lugar del vault, o viceversa) **o** usaste `client_id` en vez de `principal_id`. |
| `KeyVaultAccessForbidden` justo tras crear la asignación | Propagación RBAC: ~5 min. Espera y reintenta. |
| `terraform destroy` falla con `vault with purge protection cannot be deleted` | Exacto lo que dice. En dev deja `purge_protection_enabled = false`. En prod no destruyas, migra. |
| App Service lee el valor literal `@Microsoft.KeyVault(...)` en lugar del secret | Sintaxis de la referencia mal escrita, o la MI no tiene `Key Vault Secrets User`, o `enable_rbac_authorization` está desactivado y no hay access policy. |
| Cert `AutoRenew` no se renueva | Issuer integrado sin credenciales configuradas, o la MI del vault no tiene permisos para el issuer, o `daysBeforeExpiry` mal configurado. |

---

## Referencias

- `../examples/01-key-vault-rbac-dataplane/README.md`
- `../examples/02-container-app-reads-secret-with-mi/README.md`
- `../examples/03-aks-csi-driver-kv/README.md`
- `../resources/links.md`
