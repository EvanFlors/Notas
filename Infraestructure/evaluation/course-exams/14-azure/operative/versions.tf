terraform {
  required_version = ">= 1.6.0"

  # BUG intencional (OP-task-1):
  # - Falta el provider `azuread` que `azuread_application` y `azuread_service_principal`
  #   requieren (hoy fallan en `terraform validate` por eso).
  # - El pinning de `azurerm` es laxo (sin `~>`) y apunta a una minor que no existe.
  # Debes dejarlo correcto en pinning con `~>` sobre una minor estable (p. ej. 3.100).
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {}

  # Dummy — no se usa en `terraform validate` sin backend ni plan.
  subscription_id = "00000000-0000-0000-0000-000000000020"
  tenant_id       = "00000000-0000-0000-0000-000000000001"
}
