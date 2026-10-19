variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Name of the resource group holding the capstone dev environment."
  type        = string
  default     = "rg-capstone-dev"
}

variable "key_vault_name" {
  description = "Globally unique name of the Key Vault (3-24 chars, alphanum + dashes)."
  type        = string
  default     = "kv-capstone-dev"
}

variable "identity_name" {
  description = "Name of the User-Assigned Managed Identity consumed by the capstone app."
  type        = string
  default     = "id-capstone-api"
}
