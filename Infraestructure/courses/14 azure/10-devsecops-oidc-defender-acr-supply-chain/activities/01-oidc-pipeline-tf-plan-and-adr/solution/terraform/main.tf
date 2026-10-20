terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.50"
    }
  }
}

# Placeholder IDs. Replace from a per-env tfvars file in Phase 4.
# NEVER commit real tenant/subscription IDs here.
provider "azurerm" {
  features {}
  tenant_id       = "00000000-0000-0000-0000-000000000000"
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

provider "azuread" {
  tenant_id = "00000000-0000-0000-0000-000000000000"
}
