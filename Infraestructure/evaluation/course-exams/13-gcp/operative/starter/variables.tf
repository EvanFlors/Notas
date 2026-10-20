variable "project_prod" {
  type        = string
  description = "Project ID for the production workload (placeholder)."
  default     = "my-org-prod-123"
}

variable "project_shared" {
  type        = string
  description = "Project ID for shared services (WIF pool, BigQuery audit sink)."
  default     = "my-org-shared-456"
}

variable "project_number" {
  type        = string
  description = "Numeric project number for PROJECT_SHARED (placeholder)."
  default     = "111111111111"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "github_org" {
  type    = string
  default = "my-github-org"
}

variable "github_repo" {
  type    = string
  default = "payments-service"
}

variable "deploy_sa_email" {
  type    = string
  default = "deploy@my-org-prod-123.iam.gserviceaccount.com"
}

variable "cluster_resource_name" {
  type    = string
  default = "projects/my-org-prod-123/locations/us-central1/clusters/gke-prod"
}

variable "attestor_name" {
  type    = string
  default = "cosign-prod-attestor"
}

variable "bq_dataset" {
  type    = string
  default = "audit_logs"
}
