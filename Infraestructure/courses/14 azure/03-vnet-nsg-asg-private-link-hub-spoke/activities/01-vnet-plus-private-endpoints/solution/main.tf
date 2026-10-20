terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
  # subscription_id se inyecta via env ARM_SUBSCRIPTION_ID. No se hardcodea.
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    env       = "dev"
    workload  = "checkout"
    managedby = "terraform"
  }
}

# ---------------------------------------------------------------------------
# VNet + subnets
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "vnet-checkout-dev"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.address_space
  tags                = azurerm_resource_group.main.tags
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "pe" {
  name                 = "snet-pe"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.2.0/27"]
}

# ---------------------------------------------------------------------------
# Application Security Groups (uno por rol logico)
# ---------------------------------------------------------------------------
resource "azurerm_application_security_group" "app" {
  name                = "asg-app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_application_security_group" "pe" {
  name                = "asg-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# ---------------------------------------------------------------------------
# Network Security Group + reglas (apoyadas en ASG, no en CIDRs)
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "app" {
  name                = "nsg-app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Allow entrante HTTPS a la app
resource "azurerm_network_security_rule" "allow_https_in" {
  name                                       = "AllowHTTPSInToApp"
  priority                                   = 100
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "443"
  source_address_prefix                      = "Internet"
  destination_application_security_group_ids = [azurerm_application_security_group.app.id]
  resource_group_name                        = azurerm_resource_group.main.name
  network_security_group_name                = azurerm_network_security_group.app.name
}

# Allow asg-app -> asg-pe (acceso privado a PaaS via PE)
resource "azurerm_network_security_rule" "allow_app_to_pe" {
  name                                       = "AllowAppToPrivateEndpoints"
  priority                                   = 200
  direction                                  = "Outbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "443"
  source_application_security_group_ids      = [azurerm_application_security_group.app.id]
  destination_application_security_group_ids = [azurerm_application_security_group.pe.id]
  resource_group_name                        = azurerm_resource_group.main.name
  network_security_group_name                = azurerm_network_security_group.app.name
}

# Deny explicito: nadie entra a los PE desde internet
resource "azurerm_network_security_rule" "deny_internet_to_pe" {
  name                                       = "DenyInternetToPE"
  priority                                   = 300
  direction                                  = "Inbound"
  access                                     = "Deny"
  protocol                                   = "*"
  source_port_range                          = "*"
  destination_port_range                     = "*"
  source_address_prefix                      = "Internet"
  destination_application_security_group_ids = [azurerm_application_security_group.pe.id]
  resource_group_name                        = azurerm_resource_group.main.name
  network_security_group_name                = azurerm_network_security_group.app.name
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# ---------------------------------------------------------------------------
# Storage Account (publico desactivado)
# ---------------------------------------------------------------------------
resource "random_string" "sa_suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_storage_account" "main" {
  name                            = "stcheckoutdev${random_string.sa_suffix.result}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  tags                            = azurerm_resource_group.main.tags
}

# ---------------------------------------------------------------------------
# Key Vault (publico desactivado)
# ---------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                          = "kv-checkout-dev-${random_string.sa_suffix.result}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  public_network_access_enabled = false
  enable_rbac_authorization     = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = azurerm_resource_group.main.tags
}

# ---------------------------------------------------------------------------
# Private DNS Zones + links a la VNet
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_vnet" {
  name                  = "link-blob-vnet-checkout-dev"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_vnet" {
  name                  = "link-kv-vnet-checkout-dev"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

# ---------------------------------------------------------------------------
# Private Endpoints
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-storage-blob"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.pe.id
  tags                = azurerm_resource_group.main.tags

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

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-key-vault"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.pe.id
  tags                = azurerm_resource_group.main.tags

  private_service_connection {
    name                           = "psc-key-vault"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv.id]
  }
}
