variable "location" {
  type        = string
  default     = "westeurope"
  description = "Region Azure para todos los recursos (constraint: Europa, GDPR + PCI-light)"
}

variable "resource_group_name" {
  type        = string
  default     = "rg-checkout-dev-weu"
  description = "Nombre del Resource Group que agrupa el workload"
}

variable "address_space" {
  type        = list(string)
  default     = ["10.10.0.0/16"]
  description = "CIDR de la VNet. 10.10.0.0/16 reserva 10.11-10.19 para checkout-prod y 10.20+ para shared-services (ver ADR)"
}
