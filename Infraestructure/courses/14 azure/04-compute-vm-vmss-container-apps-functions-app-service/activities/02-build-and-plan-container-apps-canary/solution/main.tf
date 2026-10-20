terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
  # Deliberately no subscription_id / tenant_id hardcoded.
  # Credentials come from `az login` or OIDC in CI.
  skip_provider_registration = true
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-checkout-canary"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-checkout-canary"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "env" {
  name                       = "cae-checkout-canary"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}

resource "azurerm_container_app" "api" {
  name                         = "ca-checkout"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Multiple"

  identity {
    type = "SystemAssigned"
  }

  template {
    container {
      name   = "api"
      image  = var.image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "APP_VERSION"
        value = "v2"
      }
    }

    min_replicas    = 1
    max_replicas    = 10
    revision_suffix = "v2"

    http_scale_rule {
      name                = "http-concurrency"
      concurrent_requests = 50
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "auto"

    traffic_weight {
      revision_suffix = "v1"
      percentage      = 90
    }
    traffic_weight {
      revision_suffix = "v2"
      percentage      = 10
    }
  }
}

output "fqdn" {
  value       = azurerm_container_app.api.ingress[0].fqdn
  description = "Public FQDN of the Container App ingress."
}
