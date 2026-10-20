# Starter — az-03-01-vnet-plus-private-endpoints

Esta actividad es **independiente**. Tu entregable son 3 archivos Terraform + 1 ADR Markdown que escribes tú.

## Pasos

1. Lee `../README.md` completo y recorre los 3 `examples/` del módulo (sobre todo 01 y 02).
2. Prepara el directorio de trabajo:
   ```bash
   mkdir -p /tmp/az-03-01-vnet-pe
   cd /tmp/az-03-01-vnet-pe
   ```
3. Escribe los archivos:
   - `main.tf` — RG, VNet, 2 subnets, NSG + reglas, 2 ASG, Storage, Key Vault, 2 Private Endpoints, 2 Private DNS Zones, 2 links a VNet.
   - `variables.tf` — al menos `location`, `address_space`, `resource_group_name`.
   - `outputs.tf` — al menos `vnet_id`, `private_endpoint_storage_ip`.
   - `ADR-VNET-DESIGN.md` — con las 6 secciones ADR, diagrama ASCII y justificaciones.
4. (Opcional) Valida el HCL offline:
   ```bash
   terraform init -backend=false
   terraform validate
   terraform fmt -check -recursive
   ```
5. Ejecuta el validador estructural:
   ```bash
   bash <ruta-repo>/courses/azure/03-vnet-nsg-asg-private-link-hub-spoke/activities/01-vnet-plus-private-endpoints/tests/validate.sh /tmp/az-03-01-vnet-pe
   ```
6. Compara con `../solution/` para autoevaluarte.

## Reglas duras

- **No ejecutes `terraform apply`**. No hay suscripción detrás de este laboratorio.
- **No pongas IDs reales** de tenant ni de subscription. Usa `00000000-0000-0000-0000-000000000000` si necesitas placeholders.
- **Español en prosa** (comentarios narrativos del ADR); **inglés en código** (nombres de recursos, variables Terraform, snippets).

## Plantilla sugerida (`main.tf`)

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Nota: subscription_id se inyecta via env ARM_SUBSCRIPTION_ID en Fase 4.
  # Aqui NO se hardcodea para evitar fugas accidentales.
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-checkout-dev"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.address_space
}

# ... completa con subnets, NSG, reglas, ASG, Storage, Key Vault, PEs, zonas DNS ...
```

## Plantilla sugerida (`variables.tf`)

```hcl
variable "location" {
  type        = string
  default     = "westeurope"
  description = "Region Azure"
}

variable "resource_group_name" {
  type        = string
  default     = "rg-checkout-dev-weu"
  description = "Nombre del Resource Group"
}

variable "address_space" {
  type        = list(string)
  default     = ["10.10.0.0/16"]
  description = "CIDR de la VNet"
}
```

## Plantilla sugerida (`outputs.tf`)

```hcl
output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "private_endpoint_storage_ip" {
  value = azurerm_private_endpoint.storage_blob.private_service_connection[0].private_ip_address
}
```
