resource "azurerm_resource_group" "spoke_b" {
  name     = "rg-spoke-b-analytics-weu"
  location = local.location
  tags     = merge(local.tags, { role = "spoke", workload = "analytics" })
}

resource "azurerm_virtual_network" "spoke_b" {
  name                = "vnet-spoke-b"
  location            = azurerm_resource_group.spoke_b.location
  resource_group_name = azurerm_resource_group.spoke_b.name
  address_space       = ["10.2.0.0/16"]
  tags                = azurerm_resource_group.spoke_b.tags
}

resource "azurerm_subnet" "spoke_b_data" {
  name                 = "snet-data"
  resource_group_name  = azurerm_resource_group.spoke_b.name
  virtual_network_name = azurerm_virtual_network.spoke_b.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_subnet" "spoke_b_pe" {
  name                 = "snet-pe"
  resource_group_name  = azurerm_resource_group.spoke_b.name
  virtual_network_name = azurerm_virtual_network.spoke_b.name
  address_prefixes     = ["10.2.2.0/27"]
}
