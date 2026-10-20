############################################################
# main.tf — Patron RECOMENDADO: VM con user-assigned Managed
# Identity leyendo secrets de Key Vault via Azure RBAC.
#
# Flujo en tiempo de ejecucion:
#   1. La app dentro de la VM pide un token a IMDS
#      (http://169.254.169.254/metadata/identity/oauth2/token).
#   2. El runtime devuelve un access token para el audience
#      https://vault.azure.net emitido por Entra ID a nombre
#      de la Managed Identity adjunta a la VM.
#   3. La app llama a GET /secrets/<name> en el Key Vault con
#      Authorization: Bearer <token>.
#   4. Key Vault valida el token y comprueba via RBAC si el
#      principalId tiene el role Key Vault Secrets User en el
#      scope del vault. Si si, devuelve el secret.
#
# NO hay client secret en ningun sitio. Azure rota el token de
# la MI cada ~24h de forma transparente.
#
# IMPORTANT: no se aplica nada. UUIDs y tenant ids son
# placeholders. Fase 4 materializa este plan con credenciales
# reales.
############################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "demo" {
  name     = "rg-mi-demo"
  location = var.location
}

# --- Managed Identity (user-assigned) ---------------------------------
# User-assigned en vez de system-assigned para sobrevivir a la
# destruccion de la VM y permitir reasignacion a la siguiente.
resource "azurerm_user_assigned_identity" "app" {
  name                = "mi-checkout-app"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
}

# --- Key Vault en modo RBAC data-plane --------------------------------
# enable_rbac_authorization = true usa Azure RBAC para controlar
# acceso a secrets/keys/certs en vez de las access policies legacy.
resource "azurerm_key_vault" "kv" {
  name                       = "kv-checkout-demo-xyz" # debe ser globalmente unico
  resource_group_name        = azurerm_resource_group.demo.name
  location                   = azurerm_resource_group.demo.location
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # true en produccion real
}

# --- Role assignment: la MI puede LEER secrets de ESTE vault ----------
# Scope estricto: el vault concreto, no el RG, no la subscription.
resource "azurerm_role_assignment" "mi_reads_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  description          = "User-assigned MI mi-checkout-app lee secrets del vault via RBAC."
}

# --- Red minima para la VM --------------------------------------------
resource "azurerm_virtual_network" "demo" {
  name                = "vnet-mi-demo"
  address_space       = ["10.42.0.0/16"]
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
}

resource "azurerm_subnet" "demo" {
  name                 = "snet-apps"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefixes     = ["10.42.1.0/24"]
}

resource "azurerm_network_interface" "app" {
  name                = "nic-checkout-app"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.demo.id
    private_ip_address_allocation = "Dynamic"
  }
}

# --- VM Linux con la Managed Identity adjunta -------------------------
# El bloque identity{} es el que hace que IMDS en la VM pueda
# emitir tokens a nombre de la MI user-assigned.
resource "azurerm_linux_virtual_machine" "app" {
  name                = "vm-checkout-app"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.app.id,
  ]

  # En produccion usar Azure AD login / Azure Bastion en vez de SSH key local.
  disable_password_authentication = true
  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-ed25519 AAAA<PUBLIC-KEY-PLACEHOLDER> azureuser@placeholder"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

############################################################
# Output del plan mental (NO terraform plan real):
#   + azurerm_resource_group.demo
#   + azurerm_user_assigned_identity.app  (principalId emitido por Entra ID)
#   + azurerm_key_vault.kv (RBAC mode)
#   + azurerm_role_assignment.mi_reads_secrets (role: Key Vault Secrets User)
#   + azurerm_virtual_network.demo + subnet + nic
#   + azurerm_linux_virtual_machine.app con identity block UserAssigned
#
# Dia 1: la app arranca, DefaultAzureCredential obtiene token via IMDS,
#        lee secret. CERO secretos en codigo o env.
# Dia 180: todo sigue funcionando identico. Azure rota tokens solo.
#          Cero intervencion humana. Cero riesgo de leak de credencial.
############################################################
