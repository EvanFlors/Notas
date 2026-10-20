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
  name     = var.resource_group_name
  location = var.location

  tags = {
    env     = "dev"
    module  = "az-06"
    purpose = "capstone-secrets"
  }
}

# User-Assigned Managed Identity que consumira el Key Vault.
# Preferida sobre System-Assigned porque:
#  - Puede reutilizarse entre varios recursos (api, worker, functions).
#  - Sobrevive al destroy/recreate del Container App.
resource "azurerm_user_assigned_identity" "app" {
  name                = var.identity_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Key Vault con RBAC data-plane (modelo moderno).
# soft_delete_retention_days y purge_protection_enabled en valores dev;
# en prod usar 90 y true respectivamente (irreversible).
resource "azurerm_key_vault" "main" {
  name                       = var.key_vault_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = {
    env    = "dev"
    module = "az-06"
  }
}

# Role assignment data-plane: Key Vault Secrets User sobre el scope del vault.
# principal_id = principal_id de la MI (NO client_id).
# scope = el vault en concreto (NO el RG) para minimo privilegio.
resource "azurerm_role_assignment" "app_reads_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# Secret dummy. El valor real jamas se commitea; aqui es placeholder.
# En Fase 4 se setea por fuera (pipeline, az keyvault secret set).
resource "azurerm_key_vault_secret" "db_conn" {
  name         = "db-connection-string"
  value        = "CHANGE-ME-DUMMY-NOT-A-REAL-SECRET"
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.app_reads_secrets]
}
