// Capstone stage 07 — Azure Container Apps + Postgres Flexible Server + Key Vault.
// Managed Identity reads the DSN secret from Key Vault at runtime.
// CI runs plan only; apply is manual.

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_tag}"
  location = var.location
  tags = {
    capstone = "07"
    project  = var.project_tag
  }
}

// ---------------------------------------------------------------------------
// User-assigned managed identity (cleaner than system-assigned for KV ACLs).
// ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "runtime" {
  name                = "id-${var.project_tag}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

// ---------------------------------------------------------------------------
// Postgres Flexible Server (private; no public access).
// ---------------------------------------------------------------------------
resource "random_password" "db" {
  length  = 24
  special = false
}

resource "azurerm_postgresql_flexible_server" "pg" {
  name                   = "pg-${var.project_tag}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = "16"
  administrator_login    = var.db_username
  administrator_password = random_password.db.result
  sku_name               = "B_Standard_B1ms"
  storage_mb             = 32768
  zone                   = "1"
  public_network_access_enabled = false
}

// ---------------------------------------------------------------------------
// Key Vault for the DSN secret.
// ---------------------------------------------------------------------------
resource "azurerm_key_vault" "kv" {
  name                       = "kv${substr(replace(var.project_tag, "-", ""), 0, 18)}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization  = true
}

resource "azurerm_role_assignment" "kv_reader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.runtime.principal_id
}

resource "azurerm_role_assignment" "kv_admin_tf" {
  // Operator running Terraform needs rights to write the initial secret.
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "db_dsn" {
  name         = "db-dsn"
  key_vault_id = azurerm_key_vault.kv.id
  value        = "postgresql://${var.db_username}:${random_password.db.result}@${azurerm_postgresql_flexible_server.pg.fqdn}:5432/postgres"

  depends_on = [azurerm_role_assignment.kv_admin_tf]
}

// ---------------------------------------------------------------------------
// Container Apps environment + the app itself.
// ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.project_tag}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "env" {
  name                       = "cae-${var.project_tag}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}

resource "azurerm_container_app" "api" {
  name                         = "ca-${var.project_tag}"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.runtime.id]
  }

  secret {
    name                = "db-dsn"
    key_vault_secret_id = azurerm_key_vault_secret.db_dsn.id
    identity            = azurerm_user_assigned_identity.runtime.id
  }

  template {
    container {
      name   = "api"
      image  = var.image_digest
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "APP_DB_DSN"
        secret_name = "db-dsn"
      }
    }

    min_replicas = 1
    max_replicas = 5
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  depends_on = [azurerm_role_assignment.kv_reader]
}
