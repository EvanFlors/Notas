variable "project" {
  description = "Short name used as prefix for resources."
  type        = string
  default     = "capstone"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

variable "vnet_cidr" {
  description = "CIDR block for the VNet."
  type        = string
  default     = "10.40.0.0/16"
}

variable "subnet_cidrs" {
  description = "CIDR blocks for subnets."
  type = object({
    app = string
    db  = string
  })
  default = {
    app = "10.40.1.0/24"
    db  = "10.40.2.0/24"
  }
}

variable "github_org" {
  description = "GitHub org/user for federated credentials (declared, not applied)."
  type        = string
  default     = "example-org"
}

variable "github_repo" {
  description = "GitHub repository for federated credentials."
  type        = string
  default     = "capstone"
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default = {
    project = "capstone"
    stage   = "06-terraform-local-to-cloud-minimum"
    managed = "terraform"
  }
}
