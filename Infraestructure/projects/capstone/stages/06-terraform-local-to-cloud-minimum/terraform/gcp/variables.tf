variable "project_id" {
  description = "GCP project id. Do NOT commit a real project id."
  type        = string
  default     = "example-project-id"
}

variable "project" {
  description = "Short name used as prefix for resources."
  type        = string
  default     = "capstone"
}

variable "region" {
  description = "GCP region."
  type        = string
  default     = "us-central1"
}

variable "vpc_cidr_primary" {
  description = "Primary CIDR for the private subnet."
  type        = string
  default     = "10.30.0.0/20"
}

variable "github_org" {
  description = "GitHub org/user for Workload Identity Federation (declared, not applied here)."
  type        = string
  default     = "example-org"
}

variable "github_repo" {
  description = "GitHub repository for WIF."
  type        = string
  default     = "capstone"
}

variable "labels" {
  description = "Common labels applied to resources."
  type        = map(string)
  default = {
    project = "capstone"
    stage   = "06-terraform-local-to-cloud-minimum"
    managed = "terraform"
  }
}
