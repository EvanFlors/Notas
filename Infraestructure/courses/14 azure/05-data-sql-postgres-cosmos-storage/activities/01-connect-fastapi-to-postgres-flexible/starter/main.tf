# starter/main.tf
# -----------------------------------------------------------------------------
# Postgres Flexible Server + Azure SQL Database — borrador recibido para audit.
# Tiene al menos UN hallazgo intencionado en el bloque de Postgres y UNO
# en el bloque de Azure SQL. Encuentralos antes de escribir TOPOLOGY.md.
#
# IMPORTANTE: este archivo NO se aplica contra Azure. Solo se usa para:
#   1) terraform init  → descarga el provider.
#   2) terraform plan  → valida HCL (fallara al pedir subscription real).
#   3) auditoria manual.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.100" }
  }
}

provider "azurerm" {
  features {}
}

variable "tenant_id"           { type = string default = "00000000-0000-0000-0000-000000000000" } # placeholder
variable "subscription_id"     { type = string default = "00000000-0000-0000-0000-000000000000" } # placeholder
variable "db_admin_group_oid"  { type = string default = "00000000-0000-0000-0000-000000000000" }

resource "azurerm_resource_group" "data" {
  name     = "rg-az05-lab-data"
  location = "westeurope"
}

# --- Red minima -------------------------------------------------------------

resource "azurerm_virtual_network" "data" {
  name                = "vnet-az05-lab"
  address_space       = ["10.50.0.0/16"]
  location            = azurerm_resource_group.data.location
  resource_group_name = azurerm_resource_group.data.name
}

resource "azurerm_subnet" "pg" {
  name                 = "snet-pg"
  resource_group_name  = azurerm_resource_group.data.name
  virtual_network_name = azurerm_virtual_network.data.name
  address_prefixes     = ["10.50.1.0/24"]

  delegation {
    name = "pg-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

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

# --- Postgres Flexible Server ----------------------------------------------
# HALLAZGO 1 (red): public_network_access_enabled = true aunque hay subnet delegada.
#                    En private access deberia ser false.
# HALLAZGO 2 (auth): password_auth_enabled = true cuando Entra ID auth ya esta on.
#                    En prod, dejar solo Entra ID y poner password_auth_enabled = false.

resource "azurerm_postgresql_flexible_server" "pg" {
  name                   = "pg-az05-lab"
  location               = azurerm_resource_group.data.location
  resource_group_name    = azurerm_resource_group.data.name
  version                = "16"
  sku_name               = "GP_Standard_D2s_v3"
  storage_mb             = 32768

  delegated_subnet_id    = azurerm_subnet.pg.id
  private_dns_zone_id    = azurerm_private_dns_zone.pg.id

  public_network_access_enabled = true   # <-- HALLAZGO: deberia ser false con private access.

  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true   # <-- HALLAZGO: dejar solo Entra ID en prod.
    tenant_id                     = var.tenant_id
  }

  administrator_login    = "dbadmin"
  administrator_password = "ChangeMe!PleaseRotate123"   # <-- HALLAZGO bonus: NUNCA en IaC.

  backup_retention_days  = 7

  depends_on = [azurerm_private_dns_zone_virtual_network_link.pg]
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "appdb"
  server_id = azurerm_postgresql_flexible_server.pg.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# --- Azure SQL Database (solo para la comparativa, no se usa en la actividad)
# HALLAZGO (auth): no se configura administrator Entra ID; solo SQL login clasico.

resource "azurerm_mssql_server" "sql" {
  name                         = "sqlaz05labsrv"
  resource_group_name          = azurerm_resource_group.data.name
  location                     = azurerm_resource_group.data.location
  version                      = "12.0"
  administrator_login          = "sqladminuser"
  administrator_login_password = "ChangeMe!PleaseRotate123"   # <-- HALLAZGO: idem IaC.
  minimum_tls_version          = "1.2"
  public_network_access_enabled = true   # <-- HALLAZGO: cerrar con Private Endpoint.
}

resource "azurerm_mssql_database" "app" {
  name           = "appdb"
  server_id      = azurerm_mssql_server.sql.id
  sku_name       = "GP_S_Gen5_1"           # serverless 1 vCore
  min_capacity   = 0.5
  auto_pause_delay_in_minutes = 60
  zone_redundant = false
}
