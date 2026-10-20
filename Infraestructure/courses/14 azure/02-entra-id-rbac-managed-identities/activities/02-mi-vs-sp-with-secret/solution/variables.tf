variable "location" {
  type        = string
  default     = "westeurope"
  description = "Region Azure para todos los recursos del modulo (compliance Europa)."
}

variable "project" {
  type        = string
  default     = "checkout"
  description = "Prefijo semantico usado en nombres de recursos."
}
