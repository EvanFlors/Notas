# Ejemplo 03 — Esqueleto Hub-Spoke (1 hub + 2 spokes)

> **Lectura y análisis.** Mínima topología Hub-Spoke en Terraform con peerings bidireccionales y Private DNS Zone en el hub linkeada a los spokes.

## 1. Topología

```
                ┌──────────────────────────────────────┐
                │             HUB VNet                  │
                │        vnet-hub  10.0.0.0/22          │
                │                                       │
                │   AzureFirewallSubnet  10.0.0.0/26    │
                │   GatewaySubnet        10.0.0.64/27   │
                │   AzureBastionSubnet   10.0.0.96/27   │
                │                                       │
                │   Private DNS Zones (en RG hub):      │
                │   - privatelink.blob.core.windows.net │
                │   - privatelink.vaultcore.azure.net   │
                └────────┬──────────────────┬───────────┘
                         │ peering           │ peering
                         │ bidireccional     │ bidireccional
         ┌───────────────┘                   └────────────────┐
         ▼                                                     ▼
┌──────────────────────────┐                       ┌──────────────────────────┐
│   Spoke A (checkout)      │                       │   Spoke B (analytics)     │
│   vnet-spoke-a 10.1.0.0/16│                       │   vnet-spoke-b 10.2.0.0/16│
│                          │                       │                           │
│   snet-app  10.1.1.0/24  │                       │   snet-data 10.2.1.0/24   │
│   snet-pe   10.1.2.0/27  │                       │   snet-pe   10.2.2.0/27   │
│                          │                       │                           │
│   DNS zone link al hub   │                       │   DNS zone link al hub    │
└──────────────────────────┘                       └──────────────────────────┘

      Spoke A y Spoke B NO estan peereados entre si
      (non-transitividad -> si deben hablar, pasa por el hub)
```

## 2. HCL anotado — hub

```hcl
resource "azurerm_resource_group" "hub" {
  name     = "rg-hub-weu"
  location = "westeurope"
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = ["10.0.0.0/22"]
}

# Subnets especiales (nombres obligatorios)
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.0.0/26"]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.0.64/27"]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.0.96/27"]
}

# Private DNS Zones (centralizadas en el hub)
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.hub.name
}

resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.hub.name
}
```

## 3. HCL anotado — spokes

```hcl
resource "azurerm_resource_group" "spoke_a" {
  name     = "rg-spoke-a-weu"
  location = "westeurope"
}

resource "azurerm_virtual_network" "spoke_a" {
  name                = "vnet-spoke-a"
  location            = azurerm_resource_group.spoke_a.location
  resource_group_name = azurerm_resource_group.spoke_a.name
  address_space       = ["10.1.0.0/16"]
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

# spoke_b igual con 10.2.0.0/16 ...
```

## 4. HCL anotado — peering bidireccional

```hcl
resource "azurerm_virtual_network_peering" "hub_to_spoke_a" {
  name                      = "peer-hub-to-spoke-a"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_a.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
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
  use_remote_gateways          = false
  # use_remote_gateways = true cuando el hub tenga VPN/ExpressRoute Gateway
  # desplegado y quieras que spoke_a lo use.
}
```

## 5. HCL anotado — link de Private DNS Zone a los spokes

```hcl
resource "azurerm_private_dns_zone_virtual_network_link" "blob_spoke_a" {
  name                  = "link-blob-spoke-a"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.spoke_a.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_spoke_a" {
  name                  = "link-kv-spoke-a"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.spoke_a.id
}
```

> El link se crea en el RG donde vive la zona (el hub), pero apunta a la VNet del spoke. Es importante entender esta dirección.

## 6. Lectura dirigida

1. **¿Por qué los peerings se crean en pares?** Porque Azure no auto-crea el inverso: `hub → spoke-a` NO implica `spoke-a → hub`. Falta uno = no fluye.
2. **¿Qué permite `allow_forwarded_traffic` en `hub_to_spoke_a`?** Que el hub reenvíe tráfico que no es originado en su propia VNet (típico cuando hay un Firewall / NVA en el hub).
3. **¿Qué permitiría conectar spoke-a con spoke-b?** Dos opciones: (a) un peering adicional spoke-a ↔ spoke-b (rompe el patrón Hub-Spoke), (b) rutas via Azure Firewall en el hub con `0.0.0.0/0 → Firewall` y UDRs en los spokes. La opción (b) es la correcta.
4. **¿Por qué las Private DNS Zones viven en el hub y no en cada spoke?** Porque si cada spoke crea su propia zona, dos spokes resolviendo la misma Storage pueden hacerlo a IPs distintas o inconsistentes. Centralizar en el hub mantiene una verdad única.

## 7. Validación local

```bash
cd <ruta-del-ejemplo-copiado-a-tu-tmp>
terraform init -backend=false
terraform validate
terraform fmt -check -recursive
```

## 8. Qué llevarte

- Hub-Spoke mínimo = **1 hub con subnets especiales + Private DNS Zones** + **N spokes** + **2 peerings por spoke** + **N links de DNS por spoke**.
- Non-transitividad es una **feature**, no un bug: obliga a que todo el cross-spoke pase por el hub (y por tanto por el Firewall / policy del hub).
- Centralizar DNS en el hub es la pieza menos espectacular y la que más dolores de cabeza evita.
