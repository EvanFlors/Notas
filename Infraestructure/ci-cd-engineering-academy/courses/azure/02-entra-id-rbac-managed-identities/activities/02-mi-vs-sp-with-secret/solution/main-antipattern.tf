############################################################
# main-antipattern.tf
#
# ######## ANTI-PATTERN / ANTIPATRON — NO USAR EN PRODUCCION ########
#
# Modela el patron viejo: una app registration con un
# Service Principal al que se le genera un client secret
# (password) y se le concede Key Vault Secrets User sobre
# el vault. El secret tiene que almacenarse en algun sitio
# fuera de Azure (env var, otro vault, pipeline variable...)
# y rotarse manualmente antes de que caduque.
#
# Problemas que modeliza este archivo (y que el patron MI
# elimina):
#   - Hay material secreto que custodia una persona o un
#     sistema aparte.
#   - La rotacion es operativa y suele olvidarse.
#   - Un leak del secret concede acceso al vault hasta la
#     revocacion manual; el blast radius dura minutos u
#     horas, no segundos.
#   - La auditoria del uso del SPN mezcla autenticaciones
#     interactivas y de workload.
#
# IMPORTANT: no se aplica nada. Este archivo existe solo
# para que el walkthrough del README-INTENT.md pueda
# compararse 1:1 con main.tf en los 4 ejes (rotacion,
# blast radius, auditabilidad, recuperacion).
############################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

data "azurerm_client_config" "current" {}

# --- App registration + Service Principal -----------------------------
# Equivalente conceptual: "declaro una identidad de workload en
# Entra ID". A diferencia de una MI, YO soy responsable de
# custodiar la credencial.
resource "azuread_application" "checkout" {
  display_name = "app-checkout-legacy"
}

resource "azuread_service_principal" "checkout" {
  client_id = azuread_application.checkout.client_id
}

# --- Client secret (ANTIPATRON) ---------------------------------------
# El valor queda en el state de Terraform y hay que
# distribuirlo a quien consuma el SPN. Caduca en 6 meses.
#
# ANTIPATRON: cualquier cosa que acceda a este state (CI pipeline
# con permisos amplios, backup del state sin encriptar, developer
# con `terraform output -json`) obtiene el secret.
resource "azuread_service_principal_password" "checkout" {
  service_principal_id = azuread_service_principal.checkout.object_id
  end_date_relative    = "4320h" # ~180 dias — rotacion manual obligatoria
}

# --- Key Vault en modo RBAC data-plane --------------------------------
# Mismo vault que en main.tf para comparar manzanas con manzanas.
resource "azurerm_resource_group" "demo" {
  name     = "rg-sp-demo"
  location = var.location
}

resource "azurerm_key_vault" "kv" {
  name                       = "kv-checkout-legacy-xyz"
  resource_group_name        = azurerm_resource_group.demo.name
  location                   = azurerm_resource_group.demo.location
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
}

# --- Role assignment equivalente al de main.tf ------------------------
# Mismo role, mismo scope. La UNICA diferencia operativa real es
# el camino por el que el workload obtiene el token.
resource "azurerm_role_assignment" "sp_reads_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_service_principal.checkout.object_id
  description          = "SP checkout-legacy lee secrets del vault via RBAC (ANTIPATRON: usa client secret)."
}

############################################################
# Output del plan mental:
#   + azuread_application.checkout
#   + azuread_service_principal.checkout
#   + azuread_service_principal_password.checkout (CADUCA ~180d)
#   + azurerm_key_vault.kv (RBAC mode)
#   + azurerm_role_assignment.sp_reads_secrets
#
# Dia 1: alguien tiene que copiar el client secret al env de la
#        app (variable AZURE_CLIENT_SECRET), al CI, a su .bashrc...
# Dia 180: el secret caduca; si nadie recordo rotar, prod cae.
# Si el secret se filtra en dia 90: hay 90 dias de blast radius
#        hasta que alguien lo note y lo revoque.
############################################################
