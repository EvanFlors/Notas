############################################
# Management Groups — CAF Landing Zone (minimal)
############################################
#
# BUG intencional (OP-task-1):
# `mg-sandbox` cuelga de `mg-landing-zones`. En CAF Landing Zone correcto, sandbox
# es hermano, no hijo, para que las policies de landing-zones no se filtren a sandbox.
# Reorganiza para que la jerarquía sea:
#   Tenant Root
#     ├── mg-platform
#     ├── mg-landing-zones
#     │     ├── mg-landing-zones-prod
#     │     └── mg-landing-zones-dev
#     ├── mg-sandbox
#     └── mg-decommissioned

resource "azurerm_management_group" "platform" {
  display_name = "mg-platform"
}

resource "azurerm_management_group" "landing_zones" {
  display_name = "mg-landing-zones"
}

resource "azurerm_management_group" "landing_zones_prod" {
  display_name               = "mg-landing-zones-prod"
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

resource "azurerm_management_group" "landing_zones_dev" {
  display_name               = "mg-landing-zones-dev"
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

resource "azurerm_management_group" "sandbox" {
  display_name = "mg-sandbox"
  # BUG — en CAF, sandbox NO es hijo de landing-zones.
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

resource "azurerm_management_group" "decommissioned" {
  display_name = "mg-decommissioned"
}

############################################
# Policy baseline
############################################
#
# BUG intencional (OP-task-1):
# `deny-public-ip` está asignada al Tenant Root — rompería el plano de management y
# recursos de Microsoft/Azure. Cambia su `scope_id` a `mg-landing-zones`.

data "azurerm_policy_definition_built_in" "deny_public_ip" {
  display_name = "Not allowed resource types"
}

resource "azurerm_management_group_policy_assignment" "deny_public_ip" {
  name                 = "deny-public-ip"
  display_name         = "Deny public IP on landing zones"
  policy_definition_id = data.azurerm_policy_definition_built_in.deny_public_ip.id
  # BUG — scope incorrecto.
  management_group_id = "/providers/Microsoft.Management/managementGroups/${var.tenant_id}"

  parameters = jsonencode({
    listOfResourceTypesNotAllowed = {
      value = ["Microsoft.Network/publicIPAddresses"]
    }
  })
}

# `require-tags` debe asignarse a cada subscription, con effect `modify`
# para agregar la tag `environment` por default (no `audit`, no `deny`).
# BUG intencional: el enunciado abajo asigna solo a la subscription "prod" y usa `audit`.
# Rediseñar con `for_each` sobre `var.subscriptions` y effect `modify`.

data "azurerm_policy_definition_built_in" "require_tag_env" {
  display_name = "Require a tag on resources"
}

resource "azurerm_subscription_policy_assignment" "require_tags_prod" {
  name                 = "require-tag-environment"
  policy_definition_id = data.azurerm_policy_definition_built_in.require_tag_env.id
  subscription_id      = "/subscriptions/${var.subscriptions["prod"].id}"

  parameters = jsonencode({
    tagName = { value = "environment" }
  })

  # Hint: cuando lo refactorices a `for_each`, usa `modify` para auto-remediar
  # y pasa la Managed Identity de remediación.
}

# OP-task-1 — AÑADIR:
# Una policy assignment con effect `deployIfNotExists` que fuerce Diagnostic Setting
# en cada Storage Account nuevo, asignando `azurerm_user_assigned_identity.uami_policy_remediator`
# como `identity { type = "UserAssigned", identity_ids = [...] }`.
# Sin la identity + role assignment, la remediación NO corre.

############################################
# Resource Group + Key Vault + Storage (workload RG)
############################################

resource "azurerm_resource_group" "exam" {
  name     = "rg-exam-${var.environment}"
  location = var.location
  tags = {
    environment = var.environment
    owner       = "exam-candidate"
  }
}

# BUG intencional (OP-task-2):
# Key Vault con `enable_rbac_authorization = false` (modo access policies legacy),
# `purge_protection_enabled = false`, `public_network_access_enabled = true`.
# Cambia a: RBAC data-plane on, soft delete 90d, purge protection on, public access off.
resource "azurerm_key_vault" "exam" {
  name                = "kv-exam-${var.environment}"
  resource_group_name = azurerm_resource_group.exam.name
  location            = azurerm_resource_group.exam.location
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization     = false
  purge_protection_enabled      = false
  public_network_access_enabled = true
  soft_delete_retention_days    = 7
}

resource "azurerm_storage_account" "exam" {
  name                     = "stexam${var.environment}0001"
  resource_group_name      = azurerm_resource_group.exam.name
  location                 = azurerm_resource_group.exam.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
}

############################################
# Identities
############################################

# User-assigned MI para el workload. CORRECTA — úsala en OP-task-2.
resource "azurerm_user_assigned_identity" "uami_workload" {
  name                = "uami-workload-${var.environment}"
  resource_group_name = azurerm_resource_group.exam.name
  location            = azurerm_resource_group.exam.location
}

# User-assigned MI para la policy de remediación. Declarada pero no usada —
# conéctala al `deployIfNotExists` que vas a crear.
resource "azurerm_user_assigned_identity" "uami_policy_remediator" {
  name                = "uami-policy-remediator"
  resource_group_name = azurerm_resource_group.exam.name
  location            = azurerm_resource_group.exam.location
}

# ANTI-PATRÓN intencional (OP-task-2): SP con secret.
# Elimina ambos bloques (`azuread_application.workload` y `azuread_service_principal_password.workload_sp`).
resource "azuread_application" "workload" {
  display_name = "sp-workload-${var.environment}"
}

resource "azuread_service_principal" "workload" {
  client_id = azuread_application.workload.client_id
}

resource "azuread_service_principal_password" "workload_sp" {
  service_principal_id = azuread_service_principal.workload.id
  end_date             = "2099-01-01T00:00:00Z"
}

############################################
# Role assignments
############################################

# BUG intencional (OP-task-2): este role es demasiado amplio (`Contributor`).
# Reemplaza por `Key Vault Secrets User` y asígnalo a `uami_workload`, no al SP.
resource "azurerm_role_assignment" "workload_kv" {
  scope                = azurerm_key_vault.exam.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.workload.object_id
}

# NOTAS FINALES
# -------------
# Reemplaza este bloque de comentarios al terminar las tareas. Debe incluir:
# 1) Por qué `mg-landing-zones` es el scope correcto para `deny-public-ip` y qué
#    pasaría si lo pones en Tenant Root.
# 2) Qué garantiza `deployIfNotExists` que `audit` no garantiza, y qué permiso
#    necesita la MI de remediación.
# 3) Qué protege `purge_protection` y cuándo activarlo es un error (CI efímero).
