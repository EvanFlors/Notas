terraform {
  required_version = ">= 1.6.0"
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

resource "azurerm_resource_group" "main" {
  name     = "rg-capstone-dev"
  location = "westeurope"
}

resource "azurerm_key_vault" "main" {
  name                       = "kv-capstone-dev"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
}

# Certificate con auto-renewal 30 dias antes del expiry.
# Issuer "Self" en dev (self-signed). En prod se sustituye por DigiCert/GlobalSign
# via azurerm_key_vault_certificate_issuer con credenciales inyectadas desde otro secret.
resource "azurerm_key_vault_certificate" "tls" {
  name         = "cert-capstone-tls"
  key_vault_id = azurerm_key_vault.main.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = false
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      key_usage = [
        "digitalSignature",
        "keyEncipherment",
      ]
      subject = "CN=capstone.example.com"

      subject_alternative_names {
        dns_names = [
          "capstone.example.com",
          "www.capstone.example.com",
        ]
      }

      validity_in_months = 12
    }
  }
}
