variable "project" {
  description = "Short name used as prefix for all resources."
  type        = string
  default     = "capstone"
}

variable "region" {
  description = "AWS region for all resources in this stack."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "github_org" {
  description = "GitHub org/user for OIDC trust (not applied in this stage; used by stage 7)."
  type        = string
  default     = "example-org"
}

variable "github_repo" {
  description = "GitHub repository name for OIDC trust."
  type        = string
  default     = "capstone"
}

variable "tags" {
  description = "Common tags applied to every resource."
  type        = map(string)
  default = {
    project = "capstone"
    stage   = "06-terraform-local-to-cloud-minimum"
    managed = "terraform"
  }
}
