# Ejemplo 01 — VNet con NAT Gateway y Private Endpoint a Storage

> **Lectura y análisis.** No se ejecuta contra una suscripción real. El objetivo es leer el HCL, entender cada pieza y por qué está donde está.

## 1. Topología

```
         ┌─────────────────────────────────────────────────────────┐
         │                     VNet "vnet-app"                      │
         │                     10.20.0.0/16                         │
         │                                                           │
         │   ┌─────────────────────────┐   ┌───────────────────┐   │
         │   │     snet-app /24         │   │   snet-pe /27      │   │
         │   │  10.20.1.0/24            │   │  10.20.2.0/27      │   │
         │   │                          │   │                    │   │
         │   │  NIC-app1 (10.20.1.4)    │   │  PE-storage-blob   │   │
         │   │  NIC-app2 (10.20.1.5)    │   │  (10.20.2.4)       │   │
         │   │        │                 │   │                    │   │
         │   │        │ asociada a NSG  │   │                    │   │
         │   │        │ nsg-app         │   │                    │   │
         │   └────────┼─────────────────┘   └─────────┬──────────┘   │
         │            │                                │              │
         │            │ egress Internet                │ privado via  │
         │            ▼                                │ Private Link │
         │     ┌───────────────┐                       │              │
         │     │  NAT Gateway  │                       │              │
         │     │  pip-nat      │                       │              │
         │     └──────┬────────┘                       │              │
         └────────────┼───────────────────────────────┬┴──────────────┘
                      ▼                                ▼
                 Internet                   Storage Account "stexample"
                 (SNAT IP estática)         (resuelto por Private DNS Zone
                                             privatelink.blob.core.windows.net
                                             → 10.20.2.4)
```

## 2. Qué pretende enseñar

- La VNet tiene **dos subnets con roles distintos**: `snet-app` para VMs y `snet-pe` para Private Endpoints (dedicada, pequeña `/27`).
- El **NAT Gateway** da egress a internet con IP estática desde `snet-app`.
- El **Private Endpoint** a Blob Storage vive en `snet-pe` y **no** consume la NAT: ese tráfico es privado dentro de la VNet.
- La **Private DNS Zone** `privatelink.blob.core.windows.net` está linkeada a la VNet, de modo que `stexample.blob.core.windows.net` resuelve a `10.20.2.4` desde cualquier NIC de la VNet.

## 3. HCL anotado

```hcl
# ----- RG -----
resource "azurerm_resource_group" "main" {
  name     = "rg-example-vnet-pe"
  location = "westeurope"
}

# ----- VNet + subnets -----
resource "azurerm_virtual_network" "main" {
  name                = "vnet-app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.20.0.0/16"]
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_subnet" "pe" {
  name                 = "snet-pe"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.2.0/27"]
  # Nota: PE desactiva policies de red; en versiones recientes del provider
  # ya no se necesita el flag explicit, se gestiona por defecto.
}

# ----- NAT Gateway + IP publica -----
resource "azurerm_public_ip" "nat" {
  name                = "pip-nat"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "main" {
  name                    = "nat-main"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "app" {
  subnet_id      = azurerm_subnet.app.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# ----- Storage con public access desactivado -----
resource "azurerm_storage_account" "main" {
  name                            = "stexample0001" # debe ser globalmente unico
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
}

# ----- Private DNS Zone + link a la VNet -----
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_vnet" {
  name                  = "link-blob-vnet-app"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

# ----- Private Endpoint -----
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-storage-blob"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "psc-storage-blob"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}
```

## 4. Lectura dirigida

1. **¿Por qué `snet-pe` es `/27` y no `/24`?** Porque solo hospeda NICs de Private Endpoints; `/27` da 27 IPs útiles (menos las 5 reservadas), suficientes para muchos PEs en un entorno pequeño. Evita desperdicio.
2. **¿Qué pasa si borramos el `private_dns_zone_virtual_network_link`?** El PE sigue existiendo con su IP privada, pero la VNet deja de "saber" resolver `stexample0001.blob.core.windows.net` a esa IP. Las apps intentarán la IP pública y, con `public_network_access_enabled = false`, fallarán.
3. **¿Por qué el nombre del Storage lleva `0001`?** Los nombres de Storage son **globales** (DNS global `*.blob.core.windows.net`). Hay que sufijar para evitar colisiones.
4. **¿Por qué el NAT no está asociado a `snet-pe`?** Porque el tráfico PE es **privado dentro de la VNet**; no sale a internet y no necesita SNAT.

## 5. Cómo validarlo localmente sin coste

```bash
cd <ruta-del-ejemplo-copiado-a-tu-tmp>
terraform init -backend=false
terraform validate
terraform fmt -check -recursive
```

> No ejecutes `terraform plan` sin credenciales — fallará al intentar listar providers data sources. Y **no ejecutes `terraform apply`** aunque las tengas: este ejemplo es para leer, no para provisionar en este módulo.

## 6. Qué llevarte

- VNet + 2 subnets segregadas (**workload** y **PE**) es el patrón mínimo.
- NAT Gateway cubre egress a internet; **Private Endpoint cubre egress a PaaS**.
- La **Private DNS Zone linkeada** es la pieza que hace que el PE "funcione" transparentemente para la app.
- Sin ese link, el PE existe pero el mundo lo ignora.
