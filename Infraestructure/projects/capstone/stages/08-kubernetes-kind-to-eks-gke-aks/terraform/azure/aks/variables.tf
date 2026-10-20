variable "location" {
  type        = string
  default     = "eastus"
  description = "Region de Azure."
}

variable "resource_group_name" {
  type        = string
  default     = "rg-capstone-dummy"
  description = "Resource group donde vive AKS (del stage 6)."
}

variable "cluster_name" {
  type        = string
  default     = "capstone"
  description = "Nombre del cluster AKS."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.30"
  description = "Minor del control plane AKS."
}

variable "node_count" {
  type        = number
  default     = 2
  description = "Tamaño del node pool default."
}
