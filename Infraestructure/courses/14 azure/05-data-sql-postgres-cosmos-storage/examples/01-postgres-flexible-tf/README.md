# Ejemplo 01 — Postgres Flexible Server con Private Access (Terraform)

> Lectura y analisis. Sin ejecucion. Objetivo: fijar la forma tipica de un Postgres Flexible Server **privado** con HA zone-redundant, Entra ID auth y backups de 14 dias.

## 1. El snippet

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.100" }
  }
}

provider "azurerm" {
  features {}
  # subscription_id, tenant_id → leidos de env vars o de `az login`.
}

resource "azurerm_resource_group" "data" {
  name     = "rg-az05-data-example"
  location = "westeurope"
}

# VNet dedicada al workload de datos.
resource "azurerm_virtual_network" "data" {
  name                = "vnet-az05-data"
  address_space       = ["10.42.0.0/16"]
  location            = azurerm_resource_group.data.location
  resource_group_name = azurerm_resource_group.data.name
}

# Subnet DELEGADA a Microsoft.DBforPostgreSQL/flexibleServers.
# Esto permite "Private access" (sin IP publica, sin private endpoint).
resource "azurerm_subnet" "pg" {
  name                 = "snet-pg"
  resource_group_name  = azurerm_resource_group.data.name
  virtual_network_name = azurerm_virtual_network.data.name
  address_prefixes     = ["10.42.1.0/24"]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "pg-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Private DNS zone para resolver el hostname <name>.privatelink.postgres.database.azure.com
resource "azurerm_private_dns_zone" "pg" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.data.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "pg" {
  name                  = "pg-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.pg.name
  virtual_network_id    = azurerm_virtual_network.data.id
  resource_group_name   = azurerm_resource_group.data.name
}

resource "azurerm_postgresql_flexible_server" "pg" {
  name                   = "pg-az05-example"
  location               = azurerm_resource_group.data.location
  resource_group_name    = azurerm_resource_group.data.name
  version                = "16"
  sku_name               = "GP_Standard_D2s_v3"   # 2 vCPU, 8 GiB. B1ms para dev.
  storage_mb             = 32768
  backup_retention_days  = 14
  geo_redundant_backup_enabled = false

  # Private access: delega subnet + usa private DNS zone.
  delegated_subnet_id    = azurerm_subnet.pg.id
  private_dns_zone_id    = azurerm_private_dns_zone.pg.id
  public_network_access_enabled = false

  # Zone-redundant HA.
  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }

  # Entra ID auth. password_auth deshabilitado = cero passwords.
  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = "00000000-0000-0000-0000-000000000000"  # placeholder
  }

  # Admin Entra ID (grupo de administradores de BD).
  # El object_id debe ser un grupo de Entra ID (no un user individual).
  # administrator_login     = "db-admins"  # (opcional display name)

  maintenance_window {
    day_of_week  = 0
    start_hour   = 2
    start_minute = 0
  }

  tags = {
    env        = "example"
    managed_by = "terraform"
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.pg]
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "appdb"
  server_id = azurerm_postgresql_flexible_server.pg.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

output "pg_fqdn" {
  value = azurerm_postgresql_flexible_server.pg.fqdn
}
```

## 2. Lectura clave

1. **Subnet delegada** (`service_delegation` → `Microsoft.DBforPostgreSQL/flexibleServers`): es la *conditio sine qua non* del modelo private access. Sin la delegacion, el server no se puede atar a esa subnet.
2. **`public_network_access_enabled = false`**: cierra la superficie publica. Sin esto, el server queda en private access **y** publico simultaneamente.
3. **Private DNS zone** `privatelink.postgres.database.azure.com`: necesaria para que apps en la VNet resuelvan el FQDN del server a su IP privada. Si falta, las apps intentan resolver a la IP publica y fallan.
4. **`high_availability.mode = "ZoneRedundant"`**: standby en otra AZ. **No** disponible en tiers Burstable (B-series) ni en algunas regiones sin 3 AZs.
5. **`password_auth_enabled = false`**: elimina SQL login clasico. Toda auth pasa por tokens de Entra ID → la app se conecta con su Managed Identity.
6. **`backup_retention_days = 14`**: Azure retiene 7-35 dias (gratis el equivalente al storage del server; mas allá cobra). 7 es el minimo, 14 un buen default.
7. **Tenant ID placeholder**: nunca commitear un tenant real; se parametriza por variable en IaC productivo.

## 3. Que falta aqui (fuera del alcance del ejemplo)

- Role assignments reales en Entra ID para que la Managed Identity del consumidor haga `pg_catalog.pg_authid`-equivalente.
- Diagnostic Settings a Log Analytics (modulo `az-08`).
- Firewall rules (no aplican con private access, pero sí con public).
- NSG en la subnet (recomendado para defensa en profundidad incluso con subnet delegada).

## 4. Costes aproximados (si se aplicase)

- `GP_Standard_D2s_v3` + 32 GiB storage: ~140 USD/mes (region europea tipica).
- `B1ms` burstable (sin HA): ~15-25 USD/mes.

**No ejecutar `apply`** en este curso.
