variable "location" {
  description = "Azure region. Must be a European region for GDPR compliance."
  type        = string
  default     = "westeurope"
}

variable "image" {
  description = "Container image reference. Placeholder for offline validation."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}
