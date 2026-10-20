provider "azurerm" {
  features {}
}

############################################
# 0. Resource group — one per capstone stack
############################################

resource "azurerm_resource_group" "main" {
  name     = "${var.project}-rg"
  location = var.location
  tags     = var.tags
}

############################################
# 1. Backend infra (Storage Account + Blob container for state)
#    Account name must be globally unique and 3-24 lowercase alphanum chars.
############################################

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_storage_account" "state" {
  name                            = "${substr(var.project, 0, 10)}tf${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
  }

  tags = var.tags
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}

############################################
# 2. Network (VNet + 2 subnets + NSG)
############################################

resource "azurerm_virtual_network" "main" {
  name                = "${var.project}-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "app" {
  name                 = "${var.project}-app-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidrs.app]
}

resource "azurerm_subnet" "db" {
  name                 = "${var.project}-db-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidrs.db]
}

resource "azurerm_network_security_group" "base" {
  name                = "${var.project}-base-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  # Deny all inbound by default; stage 7 opens specific ports.
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

############################################
# 3. Container registry (ACR, private)
############################################

resource "azurerm_container_registry" "app" {
  name                = "${substr(var.project, 0, 10)}acr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

############################################
# 4. Federated identity for GitHub Actions (declared, NOT applied)
#    Stage 7 un-comments and applies.
############################################

# resource "azuread_application" "ci" {
#   display_name = "${var.project}-ci"
# }
#
# resource "azuread_application_federated_identity_credential" "github" {
#   application_object_id = azuread_application.ci.object_id
#   display_name          = "github-actions"
#   description           = "Trust GitHub Actions for ${var.github_org}/${var.github_repo}"
#   audiences             = ["api://AzureADTokenExchange"]
#   issuer                = "https://token.actions.githubusercontent.com"
#   subject               = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
# }
