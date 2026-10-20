# ============================================================================
# 4 peerings bidireccionales: hub <-> spoke-a y hub <-> spoke-b.
# NO existe peering spoke-a <-> spoke-b (patron Hub-Spoke, non-transitividad).
# ============================================================================

# ----- hub <-> spoke-a -----

resource "azurerm_virtual_network_peering" "hub_to_spoke_a" {
  name                      = "peer-hub-to-spoke-a"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_a.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true # necesario cuando el hub reenvia trafico (Firewall)
  allow_gateway_transit        = true # el hub expone el futuro VPN/ExpressRoute Gateway
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_a_to_hub" {
  name                      = "peer-spoke-a-to-hub"
  resource_group_name       = azurerm_resource_group.spoke_a.name
  virtual_network_name      = azurerm_virtual_network.spoke_a.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false # pasar a true cuando el hub tenga Gateway desplegado
}

# ----- hub <-> spoke-b -----

resource "azurerm_virtual_network_peering" "hub_to_spoke_b" {
  name                      = "peer-hub-to-spoke-b"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_b.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_b_to_hub" {
  name                      = "peer-spoke-b-to-hub"
  resource_group_name       = azurerm_resource_group.spoke_b.name
  virtual_network_name      = azurerm_virtual_network.spoke_b.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# ============================================================================
# Private DNS Zone (blob) linkeada a los 3 VNets: hub + 2 spokes.
# Centralizar en el hub evita que spokes resuelvan a IPs distintas.
# ============================================================================

resource "azurerm_private_dns_zone_virtual_network_link" "blob_hub" {
  name                  = "link-blob-vnet-hub"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_spoke_a" {
  name                  = "link-blob-vnet-spoke-a"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.spoke_a.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_spoke_b" {
  name                  = "link-blob-vnet-spoke-b"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.spoke_b.id
}

# (Para la zona kv la receta es identica; se omite por brevedad y queda
# como extension sugerida en el README.)
