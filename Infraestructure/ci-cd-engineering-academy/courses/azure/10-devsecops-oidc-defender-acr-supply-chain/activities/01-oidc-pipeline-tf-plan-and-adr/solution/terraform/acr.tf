# ACR per environment. Premium only where it earns its keep.

resource "azurerm_container_registry" "checkout_prod" {
  name                          = "acrcheckoutprod"
  resource_group_name           = "rg-checkout-prod"
  location                      = "westeurope"
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
  zone_redundancy_enabled       = true

  trust_policy {
    enabled = true
  }

  retention_policy {
    days    = 30
    enabled = true
  }
}

resource "azurerm_container_registry" "checkout_stg" {
  name                = "acrcheckoutstg"
  resource_group_name = "rg-checkout-stg"
  location            = "westeurope"
  sku                 = "Standard"
  admin_enabled       = false
}

resource "azurerm_container_registry" "checkout_dev" {
  name                = "acrcheckoutdev"
  resource_group_name = "rg-checkout-dev"
  location            = "westeurope"
  sku                 = "Standard"
  admin_enabled       = false
}
