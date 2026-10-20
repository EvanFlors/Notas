// Starter — capstone 07 activity 01 — Azure Container Apps.
// Four TODO blocks must be solved to pass the validator.

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.100" }
    random  = { source = "hashicorp/random", version = "~> 3.5" }
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
  public_network_access_enabled = false
}

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

// ---------------------------------------------------------------------------
// TODO 1 — Pin image BY DIGEST. The value passed to template.container.image
// must contain "@sha256:" literally. Use var.image_digest.
// ---------------------------------------------------------------------------
locals {
  // TODO 1: replace null with var.image_digest
  image_ref = null
}

// ---------------------------------------------------------------------------
// TODO 2 — Create a USER-ASSIGNED managed identity for the Container App
// runtime. Resource: azurerm_user_assigned_identity, name "id-${var.project_tag}".
// ---------------------------------------------------------------------------

// TODO 2 — declare resource "azurerm_user_assigned_identity" "runtime" HERE.

// ---------------------------------------------------------------------------
// TODO 3 — Create a Key Vault with RBAC enabled, assign the runtime identity
// the "Key Vault Secrets User" role on it, and write the DSN secret
// (name "db-dsn"). Also give the Terraform operator "Key Vault Secrets Officer"
// so the secret can be created during apply.
// Resources: azurerm_key_vault, azurerm_role_assignment x2, azurerm_key_vault_secret.
// ---------------------------------------------------------------------------

// TODO 3 — declare the four resources HERE.

// ---------------------------------------------------------------------------
// TODO 4 — Attach the user-assigned identity to the Container App, declare a
// `secret {}` block referencing the Key Vault secret id via that identity,
// and inject it as env.secret_name (NOT env.value) into the container.
// ---------------------------------------------------------------------------
resource "azurerm_container_app" "api" {
  name                         = "ca-${var.project_tag}"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  // TODO 4: identity { type = "UserAssigned", identity_ids = [runtime.id] }
  identity {
    type = "SystemAssigned"
  }

  // TODO 4: add a `secret {}` block referencing the KV secret id and the
  // runtime user-assigned identity.

  template {
    container {
      name   = "api"
      image  = local.image_ref
      cpu    = 0.5
      memory = "1Gi"

      // TODO 4: add env{} with name = "APP_DB_DSN" and secret_name = "db-dsn".
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
}
