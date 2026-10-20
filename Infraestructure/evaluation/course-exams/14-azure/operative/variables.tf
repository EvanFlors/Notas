variable "tenant_id" {
  description = "Dummy tenant id. Do not replace with a real one."
  type        = string
  default     = "00000000-0000-0000-0000-000000000001"
}

variable "subscriptions" {
  description = "Map of dummy subscriptions used as placeholders in policy assignments."
  type = map(object({
    id          = string
    environment = string
  }))
  default = {
    platform = {
      id          = "00000000-0000-0000-0000-000000000010"
      environment = "platform"
    }
    prod = {
      id          = "00000000-0000-0000-0000-000000000020"
      environment = "prod"
    }
    dev = {
      id          = "00000000-0000-0000-0000-000000000030"
      environment = "dev"
    }
    sandbox = {
      id          = "00000000-0000-0000-0000-000000000040"
      environment = "sandbox"
    }
  }
}

variable "location" {
  description = "Primary Azure region."
  type        = string
  default     = "westeurope"
}

# BUG intencional (OP-task-1): esta variable no tiene tipo ni `validation`.
# Debes tiparla como `string` y añadir una `validation { ... }` que acepte únicamente
# `dev`, `stg`, `prod`.
variable "environment" {
  default = "dev"
}

variable "aks_oidc_issuer_url" {
  description = "OIDC issuer URL of the AKS cluster. Dummy by default."
  type        = string
  default     = "https://westeurope.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000001/00000000-0000-0000-0000-000000000050/"
}

variable "github_repo" {
  description = "GitHub org/repo for OIDC federation. Keep the dummy placeholder — do NOT substitute with a real repo."
  type        = string
  default     = "example-org/example-repo"
}
