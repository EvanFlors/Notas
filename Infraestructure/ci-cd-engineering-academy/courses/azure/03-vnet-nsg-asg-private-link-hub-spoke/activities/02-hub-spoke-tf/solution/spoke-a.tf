resource "azurerm_resource_group" "spoke_a" {
  name     = "rg-spoke-a-checkout-weu"
  location = local.location
  tags     = merge(local.tags, { role = "spoke", workload = "checkout" })
}

resource "azurerm_virtual_network" "spoke_a" {
  name                = "vnet-spoke-a"
  location            = azurerm_resource_group.spoke_a.location
  resource_group_name = azurerm_resource_group.spoke_a.name
  address_space       = ["10.1.0.0/16"]
  tags                = azurerm_resource_group.spoke_a.tags
}

resource "azurerm_subnet" "spoke_a_app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.spoke_a.name
  virtual_network_name = azurerm_virtual_network.spoke_a.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "spoke_a_pe" {
  name                 = "snet-pe"
  resource_group_name  = azurerm_resource_group.spoke_a.name
  virtual_network_name = azurerm_virtual_network.spoke_a.name
  address_prefixes     = ["10.1.2.0/27"]
}
