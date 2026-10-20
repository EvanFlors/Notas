variable "project_id" {
  type        = string
  default     = "capstone-dummy-project"
  description = "Project ID de GCP (dummy en el aula)."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Region del cluster regional."
}

variable "cluster_name" {
  type        = string
  default     = "capstone"
  description = "Nombre del cluster GKE Autopilot."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.30"
  description = "Minor del control plane. Autopilot elige el patch."
}
