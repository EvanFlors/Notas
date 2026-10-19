# Ejemplo 01 — Key Vault con RBAC data-plane

> Lectura y análisis. Sin ejecución. Objetivo: leer un HCL de Key Vault moderno y reconocer sus 4 piezas (vault, MI, role assignment, secret).

## 1. HCL comentado

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = "rg-capstone-dev"
  location = "westeurope"
}

# Pieza 1: User-Assigned Managed Identity (recurso independiente, reutilizable).
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-capstone-api"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Pieza 2: el Key Vault con RBAC data-plane activo.
resource "azurerm_key_vault" "main" {
  name                       = "kv-capstone-dev"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true  # <-- clave: desactiva access policies legacy
  soft_delete_retention_days = 7     # en dev; en prod usa 90
  purge_protection_enabled   = false # en dev; en prod usa true
}

# Pieza 3: role assignment data-plane sobre el scope del vault.
resource "azurerm_role_assignment" "app_reads_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# Pieza 4: un secret dummy (NO es un secret real, es un placeholder).
resource "azurerm_key_vault_secret" "db_conn" {
  name         = "db-connection-string"
  value        = "CHANGE-ME-DUMMY-NOT-A-REAL-SECRET"
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.app_reads_secrets]
}
```

## 2. Lectura línea a línea (en 60 segundos)

1. **`enable_rbac_authorization = true`** → ya no hay `access_policy` block. Todo pasa por RBAC.
2. **`azurerm_user_assigned_identity`** → recurso con `id` (ARM resource ID) y `principal_id` (= `object_id` del SP subyacente). RBAC usa `principal_id`.
3. **`azurerm_role_assignment`** → `(scope, role_definition_name, principal_id)`. El scope es el vault, no el RG — mínimo privilegio.
4. **`azurerm_key_vault_secret`** con `value = "CHANGE-ME-DUMMY-NOT-A-REAL-SECRET"` → el valor **no** es un secret real. En producción el secret se escribe por fuera de Terraform (p. ej. desde Azure Pipelines con un step que lo lee de HashiCorp Vault y lo escribe).

## 3. Lo que **no** aparece y por qué

- Ningún `client_secret` del service principal.
- Ninguna `app_setting` con el valor del secret.
- Ningún `connection_strings.default = "Server=..."`.

El workload leerá el secret vía la MI + un `Key Vault Secrets User` sobre `vault.azure.net`. El HCL no sabe el valor real.

## 4. Role assignment equivalente en JSON

El mismo role assignment, si se materializa vía `az role assignment create --output json` o Deployment Stack, se ve así:

```json
{
  "roleDefinitionId": "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6",
  "principalId": "00000000-0000-0000-0000-000000000000",
  "principalType": "ServicePrincipal",
  "scope": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-capstone-dev/providers/Microsoft.KeyVault/vaults/kv-capstone-dev"
}
```

- `roleDefinitionId` termina en `4633458b-17de-408a-b874-0445c86b69e6` → ése es el GUID built-in de **Key Vault Secrets User**. Es estable; no cambia entre tenants.
- `principalType = "ServicePrincipal"` porque una MI es un SP gestionado por Azure.
- `scope` incluye el nombre del vault al final → **no** es el RG, es el recurso.

## 5. Pitfalls típicos

- **Usar `client_id` en vez de `principal_id`**. El `role_assignment` lo acepta sintácticamente (es un GUID) pero la asignación no "pega" porque el `client_id` no es el principal.
- **Scope en el RG en vez del vault**. Funciona (herencia hacia abajo) pero da a esa MI el rol sobre **todos** los vaults futuros del RG. Mínimo privilegio = scope al vault concreto.
- **Olvidar `depends_on = [azurerm_role_assignment...]`** en el secret. En el primer `apply`, Terraform podría intentar crear el secret antes de que la MI del *propio operador* tenga permisos — raro, pero ocurre con el principal que ejecuta el pipeline.
- **`enable_rbac_authorization = true` con `access_policy` block coexistiendo**. Si `enable_rbac_authorization = true`, el `access_policy` block se ignora silenciosamente. Un *footgun* clásico de migración.

## 6. Preguntas de autocomprobación

1. ¿Qué pasa si cambias `principal_id = azurerm_user_assigned_identity.app.principal_id` por `principal_id = azurerm_user_assigned_identity.app.client_id`?
2. ¿Qué rol built-in necesitarías si quisieras que la MI **cree** secretos nuevos, no solo leerlos?
3. ¿Por qué `scope` apunta al vault y no al secret concreto?
4. ¿Qué cambia si pones `soft_delete_retention_days = 90` + `purge_protection_enabled = true` y luego quieres destruir el RG?
5. En el `azurerm_key_vault_secret`, ¿cómo garantizarías que el valor nunca aparezca en el *state file* en claro?
