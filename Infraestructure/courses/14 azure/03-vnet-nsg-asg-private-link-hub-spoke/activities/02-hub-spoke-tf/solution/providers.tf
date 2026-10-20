terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  # subscription_id se inyecta via ARM_SUBSCRIPTION_ID. No se hardcodea.
}

locals {
  location = "westeurope"
  tags = {
    managedby = "terraform"
    module    = "az-03-hub-spoke"
  }
}
